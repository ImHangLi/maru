import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications

/// The rows of a tapped reminder on Today.
struct TodayFocus: Equatable {
    let id = UUID()
    let keys: Set<OccurrenceKey>
}

extension AppModel {
    /// A tap on a delivered reminder. It always opens Today, and it never records (spec 8.3, D081).
    /// When some doses of the reminder are of today, Today scrolls to their rows.
    func openReminder(_ reminder: DeliveredReminder) {
        analytics.markUsed(.notification)
        selectedTab = .today
        today.lockedTap = nil
        Task { await resolve(reminder) }
    }

    func retryLockedTap() {
        guard let reminder = today.lockedTap else { return }
        refresh()
        openReminder(reminder)
    }

    func focus(_ keys: Set<OccurrenceKey>) {
        today.focus = TodayFocus(keys: keys)
    }

    private func resolve(_ reminder: DeliveredReminder) async {
        let now = Date()
        // With no region name for the device zone, Today says why it shows no items.
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        let generation = dataGeneration
        do throws(StorageError) {
            let inputs = try await store.tapInputs()
            let resolver = ReminderTapResolver(
                now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: DefaultsTimeZoneRecord().load()
            )
            let planned: [PlannedOccurrence]
            switch resolver.resolve(reminder, items: inputs.items, schedules: inputs.schedules) {
            case let .resolved(occurrences), let .confirm(occurrences, _):
                planned = occurrences
            case .notSeries:
                // A one-time follow-up request (issue #21) or an unknown request opens Today.
                return
            }
            guard !planned.isEmpty else { return }
            let stored = try await store.stored(planned)
            // A restore replaced the data that the reads saw.
            guard generation == dataGeneration else { return }
            // A stored occurrence keeps its zone after travel, so its date can be off Today (spec 8.5).
            let todays = planned.filter {
                TodaySnapshot.isToday($0.plannedDate, in: stored[$0.key]?.occurrence.timeZone ?? $0.timeZone, at: now)
            }
            // With no dose of today, Today opens with no focus.
            guard !todays.isEmpty else { return }
            focus(Set(todays.map(\.key)))
        } catch {
            if error == .unavailable {
                // The database is protected while the iPhone is locked. Nothing is read or recorded (T40).
                today.lockedTap = reminder
            } else {
                // The refresh shows the storage problem in place of Today (spec 7.3).
                refresh()
            }
        }
    }
}
