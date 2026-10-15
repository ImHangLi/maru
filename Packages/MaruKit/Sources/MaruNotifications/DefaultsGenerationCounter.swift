import Foundation
import MaruCore

/// The durable counter of request generations (D086). The value is saved before it is used, under a lock, so no restart and
/// no change of the clock can give a number twice. It lives in the `UserDefaults` of the App Group, and all adds run in the
/// app process. It holds a number only: no item name, dose, time, or ID (spec 10).
public struct DefaultsGenerationCounter: GenerationCounter {
    private static let key = "reminders.requestGeneration"
    private static let lock = NSLock()
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func next() -> Int {
        Self.lock.withLock {
            let value = defaults.integer(forKey: Self.key) + 1
            defaults.set(value, forKey: Self.key)
            return value
        }
    }
}

/// Whether the engine moved every request of build 6 to requests with a generation (D086). It runs one time.
public struct DefaultsLegacyMigration: LegacyMigration {
    private let key: String
    nonisolated(unsafe) private let defaults: UserDefaults

    /// - Parameter name: `series` or `followUp`. Each engine moves its own requests.
    public init(name: String, defaults: UserDefaults = .standard) {
        key = "reminders.generationMigration.\(name)"
        self.defaults = defaults
    }

    public var isDone: Bool { defaults.bool(forKey: key) }
    public func markDone() { defaults.set(true, forKey: key) }
}
