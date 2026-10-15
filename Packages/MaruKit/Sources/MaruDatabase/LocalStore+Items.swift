import Foundation
import GRDB
import MaruCore

/// A change of one reminder option for every item that has a time (D085).
public enum ReminderOptionChange: Hashable, Sendable {
    /// "Remind Again" for every item: a count with an interval, or off.
    case followUp(FollowUpSetting?)
    /// A new interval for every item that has "Remind Again" on. An item with it off stays off.
    case followUpInterval(FollowUpInterval)
    case alarm(Bool)
}

extension LocalStore {
    /// Inserts the item, or updates the fields of the stored item with the same ID.
    /// An item that does not load again as the same value is `StorageError.invalidData`, and nothing changes.
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    public func save(_ item: Item, generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            try Self.upsert(item, db)
        }
    }

    /// Saves an item and its schedule in one transaction, so a failure leaves neither of them changed.
    /// The rules of `save(_:)` for an item and for a schedule apply. With no schedule, only the item changes.
    ///
    /// The same values again change nothing, so a second tap on Save does not double the item.
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    public func save(_ item: Item, schedule: Schedule?, generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            try Self.upsert(item, db)
            if let schedule {
                guard schedule.itemID == item.id else { throw StorageError.conflict }
                try Self.upsert(schedule, db)
            }
        }
    }

    /// Replaces an item with a new one in one transaction: it saves the new item and its schedule, and archives
    /// the old item (spec 3 P04, T06). The old item keeps its name, schedule, and records, so a past record still
    /// names the product of that time. No amount moves from the old item to the new one.
    ///
    /// A missing old item, or a new item with the ID of the old one, is `StorageError.conflict`, and nothing changes.
    /// The same values again change nothing, so a second tap on Save does not add a second item.
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    public func replace(
        _ oldItemID: ItemID, with item: Item, schedule: Schedule?, generation: Int = 0
    ) async throws(StorageError) {
        try await write(generation: generation) { db in
            guard item.id != oldItemID, var old = try Self.fetchItem(db, id: oldItemID) else {
                throw StorageError.conflict
            }
            if !old.isArchived {
                old.isArchived = true
                try Self.upsert(old, db)
            }
            try Self.upsert(item, db)
            if let schedule {
                guard schedule.itemID == item.id else { throw StorageError.conflict }
                try Self.upsert(schedule, db)
            }
        }
    }

    /// Deletes an item with its product versions, its schedules, its occurrences, and its intake events, in one
    /// transaction (D033). The user asks for this delete and confirms it. It is not a recovery from an error (spec 7.3).
    ///
    /// The projection rows go with the events of the same occurrences, so the event history and the projection
    /// agree for every occurrence that stays. No other item changes. A failure rolls back every delete.
    ///
    /// - Parameter generation: The generation of the data that the caller read. See `checkedWrite`.
    /// - Returns: The IDs of the deleted schedules and of their versions, or `nil` when the store has no such item.
    @discardableResult
    public func deleteItem(
        _ id: ItemID,
        generation: Int = 0
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        try await write(generation: generation) { db in
            let item: StatementArguments = ["item": id.text]
            guard try Bool.fetchOne(db, sql: "SELECT EXISTS (SELECT 1 FROM item WHERE id = :item)", arguments: item) == true else {
                return nil
            }
            let schedules = "SELECT id FROM schedule WHERE itemID = :item"
            // A scheduled occurrence has a slot of the item. An as-needed occurrence has the item itself.
            let occurrences = """
                SELECT id FROM occurrence
                WHERE itemID = :item OR slotID IN (SELECT id FROM scheduleSlot WHERE scheduleID IN (\(schedules)))
                """
            let scheduleIDs = try String.fetchAll(db, sql: schedules + " ORDER BY rowid", arguments: item)
                .map(ScheduleID.init(text:))
            let versionIDs = try String.fetchAll(
                db, sql: "SELECT id FROM scheduleVersion WHERE scheduleID IN (\(schedules))", arguments: item
            ).map(ScheduleVersionID.init(text:))
            // The foreign keys have no cascade, so each row goes before the row that it refers to.
            // One statement deletes every event of an occurrence, so the revision links do not block it.
            for sql in [
                "DELETE FROM occurrenceState WHERE occurrenceID IN (\(occurrences))",
                "DELETE FROM intakeEvent WHERE occurrenceID IN (\(occurrences))",
                "DELETE FROM occurrence WHERE id IN (\(occurrences))",
                """
                DELETE FROM scheduleVersionSlot
                WHERE scheduleVersionID IN (SELECT id FROM scheduleVersion WHERE scheduleID IN (\(schedules)))
                """,
                "DELETE FROM scheduleVersion WHERE scheduleID IN (\(schedules))",
                "DELETE FROM scheduleSlot WHERE scheduleID IN (\(schedules))",
                "DELETE FROM schedule WHERE itemID = :item",
                "DELETE FROM productVersion WHERE itemID = :item",
                "DELETE FROM item WHERE id = :item",
            ] {
                try db.execute(sql: sql, arguments: item)
            }
            return (scheduleIDs, versionIDs)
        }
    }

    private static func upsert(_ item: Item, _ db: Database) throws {
        let (preset, text): (String?, String?) = switch item.intakeNote {
        case nil: (nil, nil)
        case let .preset(preset): (preset.rawValue, nil)
        case let .text(text): (nil, text)
        }
        try db.execute(
            sql: """
                INSERT INTO item (
                    id, category, name, form, color, isArchived, intakeNotePreset, intakeNoteText, imageReference,
                    followUpCount, followUpMinutes, followUpChanged, alarm
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET
                    category = excluded.category, name = excluded.name, form = excluded.form,
                    color = excluded.color, isArchived = excluded.isArchived,
                    intakeNotePreset = excluded.intakeNotePreset, intakeNoteText = excluded.intakeNoteText,
                    imageReference = excluded.imageReference,
                    followUpCount = excluded.followUpCount, followUpMinutes = excluded.followUpMinutes,
                    followUpChanged = excluded.followUpChanged, alarm = excluded.alarm
                """,
            arguments: [
                item.id.text, item.category.rawValue, item.name, item.form.rawValue, item.color.rawValue,
                item.isArchived, preset, text, item.imageReference,
                item.followUp?.count.rawValue, item.followUp?.interval.rawValue, item.followUpChanged?.storedSeconds,
                item.alarm,
            ]
        )
        // The load path checks the row with the domain rules. A failure rolls back the write.
        guard try Self.fetchItem(db, id: item.id) == item else { throw StorageError.invalidData }
    }

    public func item(id: ItemID) async throws(StorageError) -> Item? {
        try await read { db in
            try Self.fetchItem(db, id: id)
        }
    }

    /// Every item, archived or not, in the order of the first save.
    public func items() async throws(StorageError) -> [Item] {
        try await read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
        }
    }

    /// Gives every stored item that has no follow-up the follow-up setting of version 1.0, which was one global
    /// setting (D079). The app runs it one time at the first open after the update, then removes that setting.
    /// An item keeps a setting that it has. `changed` is the time of the last change of the old setting. It goes to
    /// each item, so the limit of 12 follow-ups for a dose does not start again (D039).
    /// It blocks until the write ends, like the open.
    public func adoptFollowUpSetting(_ setting: FollowUpSetting, changed: Date? = nil) throws(StorageError) {
        do {
            try writer.write { db in
                try Self.adopt(setting, changed: changed, db)
            }
        } catch {
            throw StorageError(error)
        }
    }

    static func adopt(_ setting: FollowUpSetting, changed: Date?, _ db: Database) throws {
        try db.execute(
            sql: """
                UPDATE item SET followUpCount = ?, followUpMinutes = ?, followUpChanged = ?
                WHERE followUpCount IS NULL
                """,
            arguments: [setting.count.rawValue, setting.interval.rawValue, changed?.storedSeconds]
        )
    }

    /// Every active item that has a time, in the order of the first save. "Has a time" means that the item has a
    /// schedule: an item with no time has none, and the editor keeps no reminder option for it (D079, D085).
    public func timedItems() async throws(StorageError) -> [Item] {
        try await read { db in
            try Self.fetchTimedItems(db)
        }
    }

    /// Changes one reminder option of every active item that has a time, in one transaction (D085). An item that
    /// already has the value stays as it is. It returns the number of items that changed.
    ///
    /// A change of "Remind Again" sets `followUpChanged` of that item to `now`, as a save of the edit screen does, so
    /// the limit of 12 follow-ups for one dose holds across the change (D039, D079).
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    @discardableResult
    public func apply(
        _ change: ReminderOptionChange, toTimedItemsAt now: Date, generation: Int = 0
    ) async throws(StorageError) -> Int {
        try await write(generation: generation) { db in
            var changed = 0
            for var item in try Self.fetchTimedItems(db) {
                switch change {
                case let .followUp(setting):
                    guard item.followUp != setting else { continue }
                    item.followUp = setting
                    item.followUpChanged = now
                case let .followUpInterval(interval):
                    guard var setting = item.followUp, setting.interval != interval else { continue }
                    setting.interval = interval
                    item.followUp = setting
                    item.followUpChanged = now
                case let .alarm(isOn):
                    guard item.alarm != isOn else { continue }
                    item.alarm = isOn
                }
                try Self.upsert(item, db)
                changed += 1
            }
            return changed
        }
    }

    private static func fetchTimedItems(_ db: Database) throws -> [Item] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM item
                WHERE isArchived = 0 AND EXISTS (SELECT 1 FROM schedule WHERE schedule.itemID = item.id)
                ORDER BY rowid
                """
        ).map(decodeItem)
    }

    private static func fetchItem(_ db: Database, id: ItemID) throws -> Item? {
        try Row.fetchOne(db, sql: "SELECT * FROM item WHERE id = ?", arguments: [id.text]).map(decodeItem)
    }

    static func decodeItem(_ row: Row) throws -> Item {
        let preset: String? = try row.decode(forColumn: "intakeNotePreset")
        let text: String? = try row.decode(forColumn: "intakeNoteText")
        let image: String? = try row.decode(forColumn: "imageReference")
        let followUpCount: Int? = try row.decode(forColumn: "followUpCount")
        let followUpMinutes: Int? = try row.decode(forColumn: "followUpMinutes")
        let followUpChanged: Double? = try row.decode(forColumn: "followUpChanged")
        let followUp: FollowUpSetting?
        switch (followUpCount, followUpMinutes) {
        case (nil, nil): followUp = nil
        case let (count?, minutes?):
            guard let count = FollowUpCount(rawValue: count), let interval = FollowUpInterval(rawValue: minutes) else {
                throw StorageError.invalidData
            }
            followUp = FollowUpSetting(count: count, interval: interval)
        default: throw StorageError.invalidData
        }
        let note: IntakeNote? = switch (preset, text) {
        case (nil, nil): nil
        case let (preset?, nil): .preset(try IntakeNote.Preset(text: preset))
        case let (nil, text?): try Self.domain { try IntakeNote.custom(text) }
        case (.some, .some): throw StorageError.invalidData
        }
        return try Self.domain {
            try Item(
                id: ItemID(text: row.decode(forColumn: "id")),
                category: ItemCategory(text: row.decode(forColumn: "category")),
                name: row.decode(forColumn: "name"),
                form: ItemForm(text: row.decode(forColumn: "form")),
                color: ItemColor(text: row.decode(forColumn: "color")),
                isArchived: row.decode(forColumn: "isArchived"),
                intakeNote: note,
                imageReference: image,
                followUp: followUp,
                followUpChanged: followUpChanged.map(Date.init(storedSeconds:)),
                alarm: row.decode(forColumn: "alarm")
            )
        }
    }

    /// Builds a domain value from stored data. A domain rule that rejects the data means `invalidData`.
    static func domain<T>(_ build: () throws -> T) throws -> T {
        do {
            return try build()
        } catch let error as StorageError {
            throw error
        } catch let error as DatabaseError {
            throw error
        } catch {
            throw StorageError.invalidData
        }
    }
}
