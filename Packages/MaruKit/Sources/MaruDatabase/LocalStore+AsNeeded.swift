import Foundation
import GRDB
import MaruCore

/// One as-needed occurrence and its event history.
public struct AsNeededRecord: Hashable, Sendable {
    public let occurrence: AsNeededOccurrence
    public let record: OccurrenceRecord
}

/// The "As needed" card of one day on Today (D021).
public struct AsNeededDay: Hashable, Sendable {
    /// The items that are as needed on the date, in the order of the first save.
    public let items: [Item]
    /// The as-needed occurrences of the date with a taken or skipped state, in the order of the record.
    /// An undone dose is not in the list. An item can be in the list and not in `items`, for example after
    /// the user added a schedule to it later on the same day.
    public let records: [AsNeededRecord]
    /// When the user last took a dose of each item, also on an earlier day (D091). The time is the intake time that
    /// counts now. An item with no taken dose has no entry. An undone dose does not count.
    public let lastTaken: [ItemID: Date]
}

extension LocalStore {
    /// The record transaction of an as-needed dose (spec 7.2, D021). One transaction stores the occurrence
    /// when the store does not have it, and adds the event to its history. The rules of
    /// `record(_:scheduleVersionID:)` apply: the call returns only after the storage medium has the commit.
    ///
    /// The caller makes the occurrence and the event once for each tap, with their IDs, and keeps both.
    /// The same occurrence and event again write nothing, so a retry after `storage(.unavailable)` gives
    /// no second occurrence and no second event (D014). Send the same occurrence with a later event
    /// to correct or undo the dose.
    ///
    /// An occurrence ID that the store has with other content is `storage(.conflict)`. An unknown item is
    /// `storage(.conflict)` too. An event for another occurrence is `rejected(.wrongOccurrence)`.
    /// See `record(_:generation:)` for `generation`.
    @discardableResult
    public func recordAsNeeded(
        _ event: IntakeEvent,
        occurrence: AsNeededOccurrence,
        generation: Int = 0
    ) async throws(RecordFailure) -> OccurrenceRecord {
        try await recordAsNeeded(event, occurrence: occurrence, generation: generation, sync: Self.fullSync)
    }

    /// `sync` is for tests. See `flush`.
    func recordAsNeeded(
        _ event: IntakeEvent,
        occurrence: AsNeededOccurrence,
        generation: Int = 0,
        sync: @Sendable (Int32) -> Int32
    ) async throws(RecordFailure) -> OccurrenceRecord {
        guard event.occurrenceID == occurrence.id else { throw .rejected(.wrongOccurrence) }
        return try await commitRecord(generation: generation, sync: sync) { db in
            try db.execute(
                sql: """
                    INSERT INTO occurrence (id, itemID, plannedDate, plannedTime, timeZone, dose)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT DO NOTHING
                    """,
                arguments: [
                    occurrence.id.text, occurrence.itemID.text, try occurrence.plannedDate.text,
                    occurrence.plannedTime.text, occurrence.timeZone.identifier, occurrence.dose?.text,
                ]
            )
            guard try Self.fetchAsNeededOccurrence(db, id: occurrence.id) == occurrence else {
                throw StorageError.conflict
            }
            return try Self.append(event, db)
        }
    }

    /// An as-needed occurrence. A scheduled occurrence with this ID gives `nil`.
    public func asNeededOccurrence(id: OccurrenceID) async throws(StorageError) -> AsNeededOccurrence? {
        try await read { db in
            try Self.fetchAsNeededOccurrence(db, id: id)
        }
    }

    /// The as-needed items of a date and the doses recorded for that date, in one read.
    ///
    /// Pass the date of today in the time zone of the device. A dose belongs to the date of its record
    /// in the zone of the device at that time.
    public func asNeeded(on date: LocalDate) async throws(StorageError) -> AsNeededDay {
        try await read { db in
            let (items, schedules) = try Self.itemsAndSchedules(db)
            let occurrences = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM occurrence
                    WHERE plannedDate = ? AND itemID IS NOT NULL
                    ORDER BY rowid
                    """,
                arguments: [try date.text]
            ).map(Self.decodeAsNeededOccurrence)
            // `history(of:)` and `status(of:)` read the same way, so the history of each dose is checked
            // before an undone dose leaves the list. A dose with a broken projection is `invalidData` (spec 7.3).
            let records = try occurrences
                .map { occurrence in
                    AsNeededRecord(occurrence: occurrence, record: try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id))
                }
                .filter { $0.record.status != .unrecorded }
            // The projection names the current event of each dose. The card of the day checks its own doses above.
            var lastTaken: [ItemID: Date] = [:]
            for row in try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.itemID AS itemID, MAX(intakeEvent.occurredAt) AS occurredAt
                    FROM occurrence
                        JOIN occurrenceState ON occurrenceState.occurrenceID = occurrence.id AND occurrenceState.status = 'taken'
                        JOIN intakeEvent ON intakeEvent.id = occurrenceState.eventID
                    WHERE occurrence.itemID IS NOT NULL
                    GROUP BY occurrence.itemID
                    """
            ) {
                let seconds: Double = try row.decode(forColumn: "occurredAt")
                lastTaken[try ItemID(text: row.decode(forColumn: "itemID"))] = Date(storedSeconds: seconds)
            }
            return AsNeededDay(
                items: items.filter { $0.isAsNeeded(on: date, schedules: schedules) },
                records: records,
                lastTaken: lastTaken
            )
        }
    }

    private static func fetchAsNeededOccurrence(_ db: Database, id: OccurrenceID) throws -> AsNeededOccurrence? {
        try Row.fetchOne(
            db,
            sql: "SELECT * FROM occurrence WHERE id = ? AND itemID IS NOT NULL",
            arguments: [id.text]
        ).map(decodeAsNeededOccurrence)
    }

    static func decodeAsNeededOccurrence(_ row: Row) throws -> AsNeededOccurrence {
        // `Dose` rejects blank text, so a stored amount is never blank.
        let dose = try (row.decode(forColumn: "dose") as String?).map { text in
            guard let dose = Dose(text) else { throw DecodeRule(rule: .occurrenceRow) }
            return dose
        }
        return AsNeededOccurrence(
            id: try OccurrenceID(text: row.decode(forColumn: "id")),
            itemID: try ItemID(text: row.decode(forColumn: "itemID")),
            plannedDate: try LocalDate(text: row.decode(forColumn: "plannedDate")),
            plannedTime: try WallClockTime(text: row.decode(forColumn: "plannedTime")),
            timeZone: try NamedTimeZone(text: row.decode(forColumn: "timeZone")),
            dose: dose
        )
    }
}
