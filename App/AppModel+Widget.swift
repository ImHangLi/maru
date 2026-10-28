import AppIntents
import Foundation
import MaruCore
import MaruDatabase
import WidgetKit

extension AppModel {
    /// A tap on a widget opens Today at the slot of the link (D048), or the detail of an item over Today (D108).
    /// The link has no health data.
    func openWidgetLink(_ url: URL) {
        guard url.scheme == "maru", url.host() == "today" || url.host() == "item" else { return }
        analytics.markUsed(.widget)
        onboardingYieldsToAction()
        selectedTab = .today
        resetHistory()
        let component = url.pathComponents.dropFirst().first
        if url.host() == "item" {
            // The detail goes back to Today when the store has no such item.
            today.path = component.flatMap(UUID.init(uuidString:)).map { [ItemID($0)] } ?? []
            return
        }
        pendingWidgetPart = component.flatMap(DayPart.init(linkName:))
        showPendingWidgetSlot()
    }

    /// The widgets read again after each commit, so "Last Dose" and the counts follow a record at once (D108).
    func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Scrolls to the slot of a widget link. Before Today loads, the slot waits for the load.
    func showPendingWidgetSlot() {
        guard let part = pendingWidgetPart, case let .loaded(snapshot) = content, let day = snapshot.today else { return }
        pendingWidgetPart = nil
        guard let group = day.groups.first(where: { $0.part == part }) else { return }
        focus(Set(group.entries.map(\.occurrence.key)))
    }

    /// The tap on a gray capsule of the "Record Dose" widget (D048). The system runs it in this process.
    ///
    /// It records one dose with the transaction of the record circle and the generation check of D040, and then it
    /// runs the reminders as after a record on Today (D047). Three checks come first:
    /// - The restore epoch of the data must still be the one that the widget read. A restore changes it, also across a
    ///   relaunch, so a button from before a restore records nothing.
    /// - The dose must still be the one that the widget showed: the same occurrence and schedule version, today, and open.
    /// - The record transaction checks that the item is active and the slot is in the plan of now.
    /// A dose that is taken already needs no new event. But the first tap can have committed and failed to flush,
    /// so this path flushes again, and it also waits for the reminder run. A success needs both.
    /// In every other case, and when the database is locked or the commit fails, it records nothing, never
    /// shows a success, and asks the system to open Maru (spec 7.2).
    func takeFromWidget(_ intent: TakeDoseIntent) async throws {
        analytics.markUsed(.widget)
        // The intent can continue in front and open Today, so the onboarding waits for the next launch (D104).
        onboardingYieldsToAction()
        // The generation comes before the first await. A restore that ends after this line changes the generation
        // of the store, so the record is refused (D040). A restore that ended before it changed the epoch.
        let generation = dataGeneration
        let now = Date()
        let epoch = await store.restoreEpoch()
        if epoch == intent.epoch, intent.epoch % 2 == 0,
           let occurrenceID = UUID(uuidString: intent.occurrenceID).map({ OccurrenceID($0) }),
           let versionID = UUID(uuidString: intent.scheduleVersionID).map({ ScheduleVersionID($0) }),
           let deviceTimeZone = NamedTimeZone(device: .current, at: now),
           let target = try? await store.widgetTarget(
               of: occurrenceID, scheduleVersionID: versionID, at: now
           ) {
            switch target {
            case .alreadyTaken:
                // A restore can replace the data after the lookup. Report success only when the same data
                // still has the dose as recorded.
                if await store.flushCommits(),
                   generation == dataGeneration,
                   await store.restoreEpoch() == intent.epoch,
                   (try? await store.widgetTarget(of: occurrenceID, scheduleVersionID: versionID, at: Date())) == .alreadyTaken {
                    await waitForReminders(deviceTimeZone: deviceTimeZone)
                    return
                }
            case let .open(occurrence, record):
                var event = PendingEvent(
                    // The event revises the last event that the store read, so a second tap writes nothing (T18).
                    event: record.nextEvent(.taken, at: now, source: .app),
                    scheduleVersionID: occurrence.scheduleVersionID
                )
                event.requiresCurrentPlan = true
                event.restoreEpoch = intent.epoch
                if await commitAndWait([event], generation: generation) {
                    await waitForReminders(deviceTimeZone: deviceTimeZone)
                    return
                }
            case .none:
                break
            }
        }
        selectedTab = .today
        throw intent.needsToContinueInForegroundError(
            IntentDialog("Open Maru to record this dose."), continuation: nil
        )
    }

    /// The system can suspend the process after a background record returns, so the caller waits for the reminders and
    /// for the Live Activity (D110).
    func waitForReminders(deviceTimeZone: NamedTimeZone) async {
        _ = try? await store.reconcileReminders(at: Date(), deviceTimeZone: deviceTimeZone)
        await updateNextDoseNow()
    }
}

extension AppStore {
    /// What a tap on the "Record Dose" widget can record. See `LocalStore.widgetTarget`.
    func widgetTarget(
        of occurrenceID: OccurrenceID, scheduleVersionID: ScheduleVersionID, at now: Date
    ) async throws(StorageError) -> ReminderActionTarget {
        try await open().widgetTarget(of: occurrenceID, scheduleVersionID: scheduleVersionID, at: now)
    }
}

extension AppStore {
    /// The restore epoch of the data, or `nil` when it is not readable. See `LocalStore.restoreEpoch(in:)`.
    func restoreEpoch() -> Int? {
        (try? open())?.restoreEpoch
    }

    /// Flushes the commits to the storage medium again. See `LocalStore.flushCommits`.
    func flushCommits() -> Bool {
        (try? open())?.flushCommits() ?? false
    }
}
