import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications

extension AppModel {
    /// An action of a delivered reminder: "Taken", "Skip", "Take All", "Skip All", or "Remind in 10 min" (spec 8.3, D034, D090).
    /// The "Taken" button of an alarm for one item runs it too (D079). The system runs it in the background:
    /// after an unlock on the iPhone, or with the iPhone locked when the user chooses it on the Watch (D066).
    ///
    /// A record action goes through `LocalStore.recordOpenDoses`: one transaction that appends an event only for each dose that the
    /// reminder names and that is still open, and that passes the checks of its own. The follow-ups then update as after a
    /// record on Today. A snooze writes no record. It stores one request that the plan turns into a reminder (D090).
    ///
    /// The call returns when the record commits and the reminder update ends, or when the action fails. The system
    /// can suspend the process when the call returns, and then an old follow-up stays (D083).
    /// `ReminderTapDelegate` limits the whole call. The notice runs after it.
    ///
    /// In every other case it records nothing: another day, a late delivery, an older plan, a skipped dose, an event that is
    /// not confirmed, or a database that is locked (T15, T24, T40). A group action records the doses that pass their checks, and
    /// the notice says how many it recorded (D090).
    /// Maru can not come to the front from a background action. So the model prepares what a tap on the
    /// reminder shows, and a notification tells the user to open Maru.
    func performReminderAction(_ action: ReminderActionKind, on reminder: DeliveredReminder) async {
        analytics.markUsed(.notification)
        let now = Date()
        // The records come from this read, so they carry its generation (D040).
        let generation = dataGeneration
        guard !transfer.isRestoring, let deviceTimeZone = NamedTimeZone(device: .current, at: now) else {
            return finishWithNotice(.notSaved, reminder)
        }
        switch action {
        case .taken:
            await recordFromReminder(.taken, reminder, at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        case .skip:
            await recordFromReminder(.skipped, reminder, at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        case .snooze:
            await snoozeReminder(reminder, at: now, deviceTimeZone: deviceTimeZone)
        }
    }

    private func recordFromReminder(
        _ intake: IntakeAction, _ reminder: DeliveredReminder, at now: Date, deviceTimeZone: NamedTimeZone, generation: Int
    ) async {
        do throws(RecordFailure) {
            let result = try await store.recordOpenDoses(
                for: reminder, action: intake, at: now, deviceTimeZone: deviceTimeZone, generation: generation
            )
            // A restore replaced the data after the model read it. The store refused the record, or the model forgets it.
            guard generation == dataGeneration else { return finishWithNotice(.notSaved, reminder) }
            let recorded = result.recorded
            if !recorded.isEmpty { didCommit(recorded.map { $0.record }) }
            guard result.isFlushed else {
                // The events are stored and the flush failed. Today keeps them for a retry and shows no success (spec 7.2, D014).
                didFail(
                    recorded.map { PendingEvent(event: $0.event, scheduleVersionID: $0.scheduleVersionID) },
                    .storage(.unavailable)
                )
                return finishWithNotice(.notSaved, reminder)
            }
            // The commit starts the reminder update, as a record on Today does. Wait for the update and the Live Activity.
            // With no new record, the activity reads again, because it can show a dose that another path recorded (D110).
            if recorded.isEmpty {
                await updateNextDoseNow()
            } else {
                await waitForReminders(deviceTimeZone: deviceTimeZone)
            }
            if result.notRecordedCount > 0 {
                finishWithNotice(
                    recorded.isEmpty ? .noMatch : .partial(recorded: recorded.count, of: result.named), reminder
                )
            } else if result.doses.isEmpty {
                finishWithNotice(.noMatch, reminder)
            }
            // Every named dose has its record: nothing to do, and nothing to tell.
        } catch {
            finishWithNotice(.notSaved, reminder)
        }
    }

    private func snoozeReminder(_ reminder: DeliveredReminder, at now: Date, deviceTimeZone: NamedTimeZone) async {
        guard let entry = try? await store.snoozeEntry(for: reminder, at: now, deviceTimeZone: deviceTimeZone) else {
            return finishWithNotice(.snoozeFailed, reminder)
        }
        await store.addSnooze(entry)
        await waitForReminders(deviceTimeZone: deviceTimeZone)
    }

    /// Prepares what a tap on the reminder shows, and tells the user that the action did not do everything.
    private func finishWithNotice(_ reason: ActionNotice.Reason, _ reminder: DeliveredReminder) {
        openReminder(reminder)
        Task { await ActionNotice.send(reason) }
    }
}

extension AppStore {
    /// The one command of the record actions. See `LocalStore.recordOpenDoses`.
    func recordOpenDoses(
        for reminder: DeliveredReminder, action: IntakeAction, at now: Date, deviceTimeZone: NamedTimeZone, generation: Int
    ) async throws(RecordFailure) -> ReminderActionResult {
        try await openForRecord().recordOpenDoses(
            for: reminder,
            action: action,
            at: now,
            deviceTimeZone: deviceTimeZone,
            observedTimeZone: DefaultsTimeZoneRecord().load(),
            generation: generation
        )
    }

    /// The snooze that "Remind in 10 min" stands for. See `LocalStore.snoozeEntry`.
    func snoozeEntry(
        for reminder: DeliveredReminder, at now: Date, deviceTimeZone: NamedTimeZone
    ) async throws(StorageError) -> SnoozeEntry? {
        try await open().snoozeEntry(
            for: reminder, at: now, deviceTimeZone: deviceTimeZone, observedTimeZone: DefaultsTimeZoneRecord().load()
        )
    }
}
