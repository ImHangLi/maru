import Foundation
import MaruCore

/// The open removals of an engine in `UserDefaults.standard`, under one key for each engine.
///
/// A series request identifier has the form `series|<zone or "device">|<HH:MM>|<day>`, and a follow-up
/// identifier has the form `followup|<zone or "device@" zone>|<YYYY-MM-DD>|<HH:MM>|+<minutes>`, with the minutes
/// from the slot time to the follow-up (D079). They hold no item name,
/// no dose, and no ID of an item, a slot, or a version (spec 8.3, 10). So the set can stay outside the health database.
/// The database is not the place for it: the engine must not write to the database, and the set must be
/// readable before the plan.
public struct DefaultsRemovalLedger: RemovalLedger {
    /// The key of the ledger of `ReminderEngine`.
    public static let seriesKey = "reminders.openRemovals"
    /// The key of the ledger of `FollowUpEngine`.
    public static let followUpKey = "reminders.openFollowUpRemovals"

    private let key: String

    /// - Parameter key: The default is the key of `ReminderEngine`. Pass `followUpKey` for `FollowUpEngine`.
    public init(key: String = DefaultsRemovalLedger.seriesKey) {
        self.key = key
    }

    public func load() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    public func save(_ identifiers: Set<String>) {
        if identifiers.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(identifiers.sorted(), forKey: key)
        }
    }
}
