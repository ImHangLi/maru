import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// What the "Taken" action of a delivered reminder can record (spec 8.3, D034).
    ///
    /// `ReminderTapResolver.takenTarget` has the rules for the reminder. The store adds the stored state:
    /// the occurrence must be stored, its date must be today in its own time zone, and it must be open.
    /// A generation run comes first, so a launch by the action finds the occurrences of today.
    /// The read writes no event. The caller records with `record`, the transaction of the record circle,
    /// and the event revises the last event of the returned record, so a second event is rejected (T18).
    ///
    /// - Parameter observedTimeZone: What `TimeZoneRecord.load()` returns.
    public func actionTarget(
        of reminder: DeliveredReminder,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        observedTimeZone: ObservedTimeZone?
    ) async throws(StorageError) -> ReminderActionTarget {
        _ = try await generate(at: now, deviceTimeZone: deviceTimeZone)
        return try await read { db -> ReminderActionTarget in
            let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
            let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
                .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
            let resolver = ReminderTapResolver(now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: observedTimeZone)
            guard let planned = resolver.takenTarget(of: reminder, items: items, schedules: schedules),
                  let occurrence = try Row.fetchOne(
                      db,
                      sql: "SELECT * FROM occurrence WHERE slotID = ? AND plannedDate = ?",
                      arguments: [planned.slotID.text, planned.plannedDate.text]
                  ).map(Self.decodeOccurrence),
                  // A stored occurrence keeps its zone after travel, so its date can be another day there (spec 8.5).
                  occurrence.plannedDate == LocalDate(now, in: occurrence.timeZone)
            else { return .none }
            // A follow-up has no revision. It records only the schedule version that it was made for.
            if reminder.userInfo[FollowUpRequest.plannedDateKey] != nil,
               reminder.userInfo[FollowUpRequest.scheduleVersionIDKey] != occurrence.scheduleVersionID.text {
                return .none
            }
            let record = try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id)
            switch record.status {
            case .unrecorded: return .open(occurrence, record)
            case .taken: return .alreadyTaken
            // A skip is a choice of the user. The action does not replace it.
            case .skipped: return .none
            }
        }
    }
}
