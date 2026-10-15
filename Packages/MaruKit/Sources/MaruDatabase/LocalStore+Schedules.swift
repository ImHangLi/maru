import GRDB
import MaruCore

extension LocalStore {
    /// Stores a schedule. Slots and versions are append-only: the save adds the new ones and updates
    /// `isEnabled` and `endDate`. A schedule that does not extend the stored one is `StorageError.conflict`.
    /// A schedule that does not load again as the same value is `StorageError.invalidData`, and nothing changes.
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    public func save(_ schedule: Schedule, generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            try Self.upsert(schedule, db)
        }
    }

    static func upsert(_ schedule: Schedule, _ db: Database) throws {
        let stored = try Self.fetchSchedule(db, id: schedule.id)
        if let stored {
            guard stored.itemID == schedule.itemID,
                  schedule.slots.starts(with: stored.slots),
                  schedule.versions.starts(with: stored.versions)
            else { throw StorageError.conflict }
        }
        try db.execute(
            sql: """
                INSERT INTO schedule (id, itemID, isEnabled, endDate) VALUES (?, ?, ?, ?)
                ON CONFLICT (id) DO UPDATE SET isEnabled = excluded.isEnabled, endDate = excluded.endDate
                """,
            arguments: [schedule.id.text, schedule.itemID.text, schedule.isEnabled, schedule.endDate?.text]
        )
        for (position, slot) in schedule.slots.enumerated().dropFirst(stored?.slots.count ?? 0) {
            try db.execute(
                sql: "INSERT INTO scheduleSlot (id, scheduleID, position) VALUES (?, ?, ?)",
                arguments: [slot.id.text, schedule.id.text, position]
            )
        }
        for (position, version) in schedule.versions.enumerated().dropFirst(stored?.versions.count ?? 0) {
            try Self.insert(version, position: position, db)
        }
        // The load path checks the rows with the domain rules. A failure rolls back the write.
        guard try Self.fetchSchedule(db, id: schedule.id) == schedule else { throw StorageError.invalidData }
    }

    public func schedule(id: ScheduleID) async throws(StorageError) -> Schedule? {
        try await read { db in
            try Self.fetchSchedule(db, id: id)
        }
    }

    /// The schedules of an item, in the order of the first save.
    public func schedules(of itemID: ItemID) async throws(StorageError) -> [Schedule] {
        try await read { db in
            try String.fetchAll(db, sql: "SELECT id FROM schedule WHERE itemID = ? ORDER BY rowid", arguments: [itemID.text])
                .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
        }
    }

    private static func insert(_ version: ScheduleVersion, position: Int, _ db: Database) throws {
        let (policy, timeZone): (String, String?) = switch version.timeZonePolicy {
        case let .fixed(zone): ("fixed", zone.identifier)
        case .followsDevice: ("followsDevice", nil)
        }
        try db.execute(
            sql: """
                INSERT INTO scheduleVersion
                    (id, scheduleID, position, effectiveFrom, weekdays, cycleStart, cycleDaysOn, cycleDaysOff,
                     dose, timeZonePolicy, timeZone)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                version.id.text, version.scheduleID.text, position, version.effectiveFrom.text, version.weeklyRule.text,
                version.dayCycle?.start.text, version.dayCycle?.daysOn, version.dayCycle?.daysOff,
                version.dose?.text, policy, timeZone,
            ]
        )
        for (slotPosition, slotTime) in version.slotTimes.enumerated() {
            try db.execute(
                sql: "INSERT INTO scheduleVersionSlot (scheduleVersionID, slotID, position, time) VALUES (?, ?, ?, ?)",
                arguments: [version.id.text, slotTime.slotID.text, slotPosition, slotTime.time.text]
            )
        }
    }

    /// Loads a schedule through the domain operations, so stored data that breaks a schedule rule does not load.
    static func fetchSchedule(_ db: Database, id: ScheduleID) throws -> Schedule? {
        try named(.scheduleRow) { try fetchScheduleRow(db, id: id) }
    }

    private static func fetchScheduleRow(_ db: Database, id: ScheduleID) throws -> Schedule? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM schedule WHERE id = ?", arguments: [id.text]) else {
            return nil
        }
        let endDate: String? = try row.decode(forColumn: "endDate")
        var schedule = Schedule(
            id: id,
            itemID: try ItemID(text: row.decode(forColumn: "itemID")),
            isEnabled: try row.decode(forColumn: "isEnabled"),
            endDate: try endDate.map(LocalDate.init(text:))
        )
        let slotIDs = try String.fetchAll(
            db,
            sql: "SELECT id FROM scheduleSlot WHERE scheduleID = ? ORDER BY position",
            arguments: [id.text]
        )
        let versions = try Row.fetchAll(
            db,
            sql: "SELECT * FROM scheduleVersion WHERE scheduleID = ? ORDER BY position",
            arguments: [id.text]
        )
        try domain(.scheduleSlot) {
            for slotID in slotIDs {
                try schedule.addSlot(id: ScheduleSlotID(text: slotID))
            }
        }
        for version in versions {
            // A rule of the schedule that rejects the version gives its own rule, for example `version_order`.
            try domain(.versionRow) {
                try schedule.appendVersion(decodeVersion(version, scheduleID: id, db))
            }
        }
        return schedule
    }

    private static func decodeVersion(_ row: Row, scheduleID: ScheduleID, _ db: Database) throws -> ScheduleVersion {
        let id: String = try row.decode(forColumn: "id")
        let slotTimes = try Row.fetchAll(
            db,
            sql: "SELECT slotID, time FROM scheduleVersionSlot WHERE scheduleVersionID = ? ORDER BY position",
            arguments: [id]
        ).map { slot in
            SlotTime(
                slotID: try ScheduleSlotID(text: slot.decode(forColumn: "slotID")),
                time: try WallClockTime(text: slot.decode(forColumn: "time"))
            )
        }
        let dose = try (row.decode(forColumn: "dose") as String?).map { text in
            // `Dose` rejects blank text, so a stored dose is never blank.
            guard let dose = Dose(text) else { throw DecodeRule(rule: .versionDose) }
            return dose
        }
        let policy: String = try row.decode(forColumn: "timeZonePolicy")
        let timeZone: String? = try row.decode(forColumn: "timeZone")
        let timeZonePolicy: TimeZonePolicy = switch (policy, timeZone) {
        case let ("fixed", zone?): .fixed(try Self.named(.versionZone) { try NamedTimeZone(text: zone) })
        case ("followsDevice", nil): .followsDevice
        default: throw DecodeRule(rule: .versionZone)
        }
        let cycleStart: String? = try row.decode(forColumn: "cycleStart")
        let cycleDaysOn: Int? = try row.decode(forColumn: "cycleDaysOn")
        let cycleDaysOff: Int? = try row.decode(forColumn: "cycleDaysOff")
        let dayCycle: DayCycle? = switch (cycleStart, cycleDaysOn, cycleDaysOff) {
        case (nil, nil, nil): nil
        case let (start?, daysOn?, daysOff?):
            try Self.named(.versionCycle) { try DayCycle(start: LocalDate(text: start), daysOn: daysOn, daysOff: daysOff) }
        default: throw DecodeRule(rule: .versionCycle)
        }
        return try ScheduleVersion(
            id: ScheduleVersionID(text: id),
            scheduleID: scheduleID,
            effectiveFrom: LocalDate(text: row.decode(forColumn: "effectiveFrom")),
            weeklyRule: WeeklyRule(text: row.decode(forColumn: "weekdays")),
            dayCycle: dayCycle,
            slotTimes: slotTimes,
            dose: dose,
            timeZonePolicy: timeZonePolicy
        )
    }
}
