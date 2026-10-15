import Foundation
import MaruCore

/// The snoozes of the user in the `UserDefaults` of the App Group (D090). The value is a list of entries with a series ID,
/// a plan date, and an instant. It holds no item ID, no name, and no dose (spec 10), and it needs no database, so it works while
/// the database is locked.
///
/// Every change reads and writes under one lock, and all changes run in the app process.
public struct DefaultsSnoozeStore: SnoozeStore {
    private static let key = "reminders.snoozes"
    private static let lock = NSLock()
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [SnoozeEntry] {
        Self.lock.withLock { read() }
    }

    public func add(_ entry: SnoozeEntry) {
        Self.lock.withLock { write(MemorySnoozeStore.adding(entry, to: read())) }
    }

    public func remove(_ entries: [SnoozeEntry]) {
        Self.lock.withLock {
            let kept = read().filter { !entries.contains($0) }
            if kept.isEmpty { defaults.removeObject(forKey: Self.key) } else { write(kept) }
        }
    }

    /// A value that does not decode is no snooze. The next change replaces it.
    private func read() -> [SnoozeEntry] {
        defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([SnoozeEntry].self, from: $0) } ?? []
    }

    private func write(_ entries: [SnoozeEntry]) {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: Self.key) }
    }
}
