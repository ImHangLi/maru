import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications

extension AppModel {
    /// The "Taken" action of a delivered reminder (spec 8.3, D034). The system runs it in the background,
    /// on an unlocked iPhone.
    ///
    /// It records only when the reminder gives exactly one open dose of today, with the transaction of the
    /// record circle. The event revises the last event that the store read, so a second action writes nothing (T18).
    /// The follow-ups then update as after a record on Today.
    ///
    /// The call returns when the record commits or fails. It waits for no notification call of the system:
    /// the follow-up update and the notice run after it. `ReminderTapDelegate` also limits the whole call.
    ///
    /// In every other case it records nothing: another day, a late delivery, an older plan, two or more items,
    /// a skipped dose, an event that is not confirmed, or a database that is locked (T15, T24, T40).
    /// Maru can not come to the front from a background action. So the model prepares what a tap on the
    /// reminder shows, and a notification tells the user to open Maru.
    func takeReminder(_ reminder: DeliveredReminder) async {
        let now = Date()
        // The target comes from this read, so the record carries its generation (D040).
        let generation = dataGeneration
        if let deviceTimeZone = NamedTimeZone(device: .current, at: now),
           let target = try? await store.actionTarget(
               of: reminder, at: now, deviceTimeZone: deviceTimeZone, generation: generation
           ) {
            switch target {
            case .alreadyTaken:
                // The dose has its record. Nothing to do, and nothing to tell.
                return
            case let .open(occurrence, record):
                let event = PendingEvent(
                    event: IntakeEvent(
                        occurrenceID: occurrence.id,
                        action: .taken,
                        // The time of the action. The delivery time is not an intake time (spec 8.3).
                        occurredAt: now,
                        recordedAt: now,
                        source: .notificationAction,
                        supersedes: record.events.last?.id
                    ),
                    scheduleVersionID: occurrence.scheduleVersionID
                )
                // The commit starts the follow-up update, as a record on Today does.
                if await commitAndWait([event], generation: generation) { return }
            case .none:
                break
            }
        }
        openReminder(reminder)
        Task { await ActionNotice.send() }
    }
}

extension AppStore {
    /// What the "Taken" action of a reminder can record. See `LocalStore.actionTarget`.
    func actionTarget(
        of reminder: DeliveredReminder, at now: Date, deviceTimeZone: NamedTimeZone, generation: Int
    ) async throws(StorageError) -> ReminderActionTarget {
        try await open().actionTarget(
            of: reminder,
            at: now,
            deviceTimeZone: deviceTimeZone,
            observedTimeZone: DefaultsTimeZoneRecord().load(),
            generation: generation
        )
    }
}
