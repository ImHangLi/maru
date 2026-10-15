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

    /// The time at which each identifier entered the ledger, under a second key. An entry of an older build has no time.
    private var sinceKey: String { key + ".since" }

    public func save(_ identifiers: Set<String>) {
        let defaults = UserDefaults.standard
        if identifiers.isEmpty {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: sinceKey)
            return
        }
        let known = defaults.dictionary(forKey: sinceKey) as? [String: Date] ?? [:]
        let now = Date()
        // A new identifier gets the time of now. An identifier that stays keeps its first time.
        let times = Dictionary(uniqueKeysWithValues: identifiers.map { ($0, known[$0] ?? now) })
        defaults.set(times, forKey: sinceKey)
        defaults.set(identifiers.sorted(), forKey: key)
    }

    public func since(_ identifier: String) -> Date? {
        guard load().contains(identifier) else { return nil }
        let known = UserDefaults.standard.dictionary(forKey: sinceKey) as? [String: Date]
        return known?[identifier] ?? .distantPast
    }
}
