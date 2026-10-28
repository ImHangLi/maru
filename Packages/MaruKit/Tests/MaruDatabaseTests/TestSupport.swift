import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

/// A new database directory in the temporary folder. It is deleted when the value is released.
final class TestDirectory: Sendable {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("MaruDatabaseTests-\(UUID().uuidString)", isDirectory: true)

    var databaseFile: URL { url.appendingPathComponent(LocalStore.fileName) }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

/// An item, its twice-daily schedule, and the morning occurrence of 2026-03-01, all stored.
struct Seed {
    let item: Item
    let schedule: Schedule
    let morning: ScheduleSlotID
    let evening: ScheduleSlotID
    let occurrence: Occurrence

    var versionID: ScheduleVersionID { occurrence.scheduleVersionID }
}

enum Fixtures {
    static func date(_ year: Int, _ month: Int, _ day: Int) -> LocalDate {
        try! LocalDate(year: year, month: month, day: day)
    }

    static func time(_ hour: Int, _ minute: Int = 0) -> WallClockTime {
        try! WallClockTime(hour: hour, minute: minute)
    }

    static let shanghai = try! NamedTimeZone(identifier: "Asia/Shanghai")
    static let newYork = try! NamedTimeZone(identifier: "America/New_York")

    /// An instant from ISO 8601 text, for example `2026-03-01T04:00:00Z`.
    static func instant(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    /// A schedule with morning and evening slots and a first version, effective on 2026-01-01.
    static func twiceDailySchedule(
        itemID: ItemID,
        dose: Dose? = nil,
        timeZonePolicy: TimeZonePolicy = .fixed(shanghai)
    ) -> (schedule: Schedule, morning: ScheduleSlotID, evening: ScheduleSlotID) {
        var schedule = Schedule(itemID: itemID, isEnabled: true)
        let morning = try! schedule.addSlot().id
        let evening = try! schedule.addSlot().id
        let version = try! ScheduleVersion(
            scheduleID: schedule.id,
            effectiveFrom: date(2026, 1, 1),
            weeklyRule: .everyDay,
            slotTimes: [SlotTime(slotID: morning, time: time(8)), SlotTime(slotID: evening, time: time(20))],
            dose: dose,
            timeZonePolicy: timeZonePolicy
        )
        try! schedule.appendVersion(version)
        return (schedule, morning, evening)
    }

    static func occurrence(
        slotID: ScheduleSlotID,
        on day: LocalDate = date(2026, 3, 1),
        in schedule: Schedule
    ) -> Occurrence {
        let version = schedule.versions.last!
        return Occurrence(
            slotID: slotID,
            plannedDate: day,
            plannedTime: version.time(for: slotID)!,
            timeZone: shanghai,
            scheduleVersionID: version.id
        )
    }

    static func event(
        for occurrence: Occurrence,
        _ action: IntakeAction,
        supersedes: IntakeEventID? = nil,
        source: EventSource = .app
    ) -> IntakeEvent {
        IntakeEvent(
            occurrenceID: occurrence.id,
            action: action,
            occurredAt: Date(timeIntervalSince1970: 1_000),
            recordedAt: Date(timeIntervalSince1970: 1_001),
            source: source,
            supersedes: supersedes
        )
    }
}

extension LocalStore {
    /// The member "Me" that the migration of every database made.
    var meID: PersonID {
        try! writer.read { db in try Self.fetchPeople(db).first { $0.kind == .me }!.id }
    }

    func seed() async throws -> Seed {
        let item = try Item(personID: meID, category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        try await save(item)
        let (schedule, morning, evening) = Fixtures.twiceDailySchedule(itemID: item.id)
        try await save(schedule)
        let occurrence = Fixtures.occurrence(slotID: morning, in: schedule)
        try await save(occurrence)
        return Seed(item: item, schedule: schedule, morning: morning, evening: evening, occurrence: occurrence)
    }

    /// Stores a schedule with no day cycle in a database from before `v5`. `save` names the columns of `v5`,
    /// so a migration test writes the rows of an older schema with this.
    /// Saves an item that has no reminder options, on a database that is older than `v6`.
    func saveBeforeVersion6(_ item: Item) async throws {
        try await execute(
            "INSERT INTO item (id, category, name, form, color, isArchived) VALUES (?, ?, ?, ?, ?, ?)",
            [item.id.text, item.category.rawValue, item.name, item.form.rawValue, item.color.rawValue, item.isArchived]
        )
    }

    func saveBeforeVersion4(_ schedule: Schedule) async throws {
        try await execute(
            "INSERT INTO schedule (id, itemID, isEnabled, endDate) VALUES (?, ?, ?, NULL)",
            [schedule.id.text, schedule.itemID.text, schedule.isEnabled]
        )
        for (position, slot) in schedule.slots.enumerated() {
            try await execute(
                "INSERT INTO scheduleSlot (id, scheduleID, position) VALUES (?, ?, ?)", [slot.id.text, schedule.id.text, position]
            )
        }
        for (position, version) in schedule.versions.enumerated() {
            guard case let .fixed(zone) = version.timeZonePolicy else { continue }
            try await execute(
                """
                INSERT INTO scheduleVersion (id, scheduleID, position, effectiveFrom, weekdays, dose, timeZonePolicy, timeZone)
                VALUES (?, ?, ?, ?, ?, ?, 'fixed', ?)
                """,
                [
                    version.id.text, schedule.id.text, position, try version.effectiveFrom.text, version.weeklyRule.text,
                    version.dose?.text, zone.identifier,
                ]
            )
            for (slotPosition, slotTime) in version.slotTimes.enumerated() {
                try await execute(
                    "INSERT INTO scheduleVersionSlot (scheduleVersionID, slotID, position, time) VALUES (?, ?, ?, ?)",
                    [version.id.text, slotTime.slotID.text, slotPosition, slotTime.time.text]
                )
            }
        }
    }

    /// Runs raw SQL on the database. Tests use it to inject faults and to read tables directly.
    func execute(_ sql: String, _ arguments: StatementArguments = StatementArguments()) async throws {
        try await writer.writeWithoutTransaction { db in
            try db.execute(sql: sql, arguments: arguments)
        }
    }

    func count(_ table: String) async throws -> Int {
        try await writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)")!
        }
    }

    /// Checks that the event table, the projection, and both read operations agree (T20).
    func expectConsistent(
        _ occurrence: Occurrence,
        events: [IntakeEvent],
        status: OccurrenceStatus,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        let history = try await history(of: occurrence.id)
        #expect(history.events == events, sourceLocation: sourceLocation)
        #expect(history.status == status, sourceLocation: sourceLocation)
        #expect(try await self.status(of: occurrence.id) == status, sourceLocation: sourceLocation)
        let states = try await writer.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT eventID, status FROM occurrenceState WHERE occurrenceID = ?",
                arguments: [occurrence.id.rawValue.uuidString]
            ).map { row in [row["eventID"] as String, row["status"] as String] }
        }
        let expected = history.currentEvent.map { [[$0.id.rawValue.uuidString, $0.action.rawValue]] } ?? []
        #expect(states == expected, sourceLocation: sourceLocation)
    }
}
