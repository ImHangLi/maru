import Foundation
import GRDB
import MaruCore

extension LocalStore: ReminderPlanSource {
    /// The reminders that the stored items and schedules ask for (spec 8.1). `ReminderPlan` has the rules.
    ///
    /// One read gives the items and the schedules, so the plan is the state of one commit.
    /// The schedules are in the order of the first save. The store keeps no state of the reminders.
    ///
    /// - Parameters:
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the schedule versions that follow it.
    ///   - privacy: Whether the reminder text names the items (D029).
    ///   - alarmsRing: Alarms can ring now, so the plan leaves out the items with an alarm (D079).
    public func reminderPlan(
        at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarmsRing: Bool = false
    ) async throws(StorageError) -> ReminderPlan {
        try await read { db in
            let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
            let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
                .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
            // An occurrence is closed when its projection row says taken or skipped (D047).
            let dates = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone).candidateDates
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.slotID, occurrence.plannedDate FROM occurrence
                    JOIN occurrenceState ON occurrenceState.occurrenceID = occurrence.id
                    WHERE occurrence.plannedDate BETWEEN ? AND ?
                    """,
                arguments: [try dates[0].text, try dates[dates.count - 1].text]
            )
            let closed = Set(try rows.map { row in
                OccurrenceKey(
                    slotID: try ScheduleSlotID(text: row.decode(forColumn: "slotID")),
                    plannedDate: try LocalDate(text: row.decode(forColumn: "plannedDate"))
                )
            })
            return ReminderPlan(
                items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy, closed: closed,
                alarmsRing: alarmsRing
            )
        }
    }
}
