import Foundation

/// Before D086, the removal ledger stored open removals in `UserDefaults`.
/// Fresh request identifiers replace the ledger. Each store initialization removes its old keys.
public enum LegacyRemovalLedger {
    private static let keys = ["reminders.openRemovals", "reminders.openRemovals.since", "reminders.openFollowUpRemovals", "reminders.openFollowUpRemovals.since"]

    public static func remove(in defaults: UserDefaults = .standard) {
        for key in keys { defaults.removeObject(forKey: key) }
    }
}
