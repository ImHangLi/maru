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
    public func reminderPlan(
        at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy
    ) async throws(StorageError) -> ReminderPlan {
        try await read { db in
            let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
            let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
                .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
            return ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy)
        }
    }
}
