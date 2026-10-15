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
    ///   - alarms: Which items an alarm covers now, so the plan leaves them out (D079).
    public func reminderPlan(
        at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover = .none
    ) async throws -> ReminderPlan {
        try await readPlan { db in
            let (items, schedules, unreadable) = try Self.planInputs(db)
            // An occurrence is closed when its projection row says taken or skipped (D047). A dose of an as-needed item has
            // no slot and no reminder, so the query leaves it out. Before D088 it stopped every run with `invalidData`.
            let dates = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone).candidateDates
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.slotID, occurrence.plannedDate FROM occurrence
                    JOIN occurrenceState ON occurrenceState.occurrenceID = occurrence.id
                    WHERE occurrence.slotID IS NOT NULL AND occurrence.plannedDate BETWEEN ? AND ?
                    """,
                arguments: [try dates[0].text, try dates[dates.count - 1].text]
            )
            let closed = try Self.named(.occurrenceRow) { try Set(rows.map { row in
                OccurrenceKey(
                    slotID: try ScheduleSlotID(text: row.decode(forColumn: "slotID")),
                    plannedDate: try LocalDate(text: row.decode(forColumn: "plannedDate"))
                )
            }) }
            return ReminderPlan(
                items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy, closed: closed,
                alarms: alarms, unreadable: unreadable
            )
        }
    }
}
