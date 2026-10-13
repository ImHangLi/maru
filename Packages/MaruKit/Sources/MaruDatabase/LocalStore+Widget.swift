import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// What a tap on a gray capsule of the "Record Dose" widget can record (D048).
    ///
    /// The widget shows an occurrence and the schedule version that it had when the timeline was made.
    /// The target is open only when the stored occurrence is still that one, its date is today in its own
    /// time zone, and it has no taken or skipped state. A plan change in between, another day, and a skip
    /// give `.none`, so the widget records nothing and sends the user to the app. A taken dose gives `.alreadyTaken`.
    /// The read writes no event. The caller records with `record`, and the event revises the last event of the
    /// returned record, so a second event is rejected (T18).
    public func widgetTarget(
        of occurrenceID: OccurrenceID, scheduleVersionID: ScheduleVersionID, at now: Date
    ) async throws(StorageError) -> ReminderActionTarget {
        try await read { db -> ReminderActionTarget in
            guard let occurrence = try Row.fetchOne(
                      db, sql: "SELECT * FROM occurrence WHERE id = ?", arguments: [occurrenceID.text]
                  ).map(Self.decodeOccurrence),
                  occurrence.scheduleVersionID == scheduleVersionID,
                  occurrence.plannedDate == LocalDate(now, in: occurrence.timeZone)
            else { return .none }
            let record = try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id)
            switch record.status {
            case .unrecorded: return .open(occurrence, record)
            case .taken: return .alreadyTaken
            case .skipped: return .none
            }
        }
    }
}
