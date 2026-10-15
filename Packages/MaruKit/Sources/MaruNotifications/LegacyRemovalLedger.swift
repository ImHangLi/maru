import Foundation

/// The removal ledger of builds before D086 kept its open removals in `UserDefaults`. The app has no ledger now, because a
/// request that it adds later has another identifier, so no removal can delete it. This removes the old keys one time.
public enum LegacyRemovalLedger {
    private static let keys = ["reminders.openRemovals", "reminders.openRemovals.since", "reminders.openFollowUpRemovals", "reminders.openFollowUpRemovals.since"]

    public static func remove(in defaults: UserDefaults = .standard) {
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
