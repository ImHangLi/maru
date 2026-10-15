import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// What the "Taken" action of a delivered reminder can record (spec 8.3, D034).
    ///
    /// `ReminderTapResolver.takenTarget` has the rules for the reminder. The store adds the stored state:
    /// the occurrence must be stored, its date must be today in its own time zone, and it must be open.
    /// For a follow-up, the date can also be the day before, until `FollowUpPlan.latestTime` (D039).
    /// A generation run comes first, so a launch by the action finds the occurrences of yesterday and today.
    /// The read writes no event. The caller records with `record`, the transaction of the record circle,
    /// and the event revises the last event of the returned record, so a second event is rejected (T18).
    ///
    /// - Parameters:
    ///   - observedTimeZone: What `DefaultsTimeZoneRecord.load()` returns.
    ///   - generation: The generation of the data that the caller read. See `checkedWrite`.
    public func actionTarget(
        of reminder: DeliveredReminder,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        observedTimeZone: ObservedTimeZone?,
        generation: Int = 0
    ) async throws(StorageError) -> ReminderActionTarget {
        _ = try await generate(at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        return try await read { db -> ReminderActionTarget in
            let (items, schedules) = try Self.itemsAndSchedules(db)
            let resolver = ReminderTapResolver(now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: observedTimeZone)
            guard let planned = resolver.takenTarget(of: reminder, items: items, schedules: schedules),
                  let occurrence = try Row.fetchOne(
                      db,
                      sql: "SELECT * FROM occurrence WHERE slotID = ? AND plannedDate = ?",
                      arguments: [planned.slotID.text, planned.plannedDate.text]
                  ).map(Self.decodeOccurrence),
                  // A stored occurrence keeps its zone after travel, so its date can be another day there (spec 8.5).
                  // A follow-up can also stand for the dose of the day before, until a time after midnight (D039).
                  reminder.userInfo[FollowUpRequest.plannedDateKey] != nil
                      ? FollowUpPlan.takesDose(on: occurrence.plannedDate, at: now, in: occurrence.timeZone)
                      : occurrence.plannedDate == LocalDate(now, in: occurrence.timeZone)
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
