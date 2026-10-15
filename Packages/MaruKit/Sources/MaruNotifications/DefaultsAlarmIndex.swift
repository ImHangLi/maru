import Foundation
import MaruCore

/// The index of alarms in the `UserDefaults` of the App Group (D089): the identifier of each alarm and the IDs of its schedules.
/// It holds no name, no dose, and no time. It stays on the device, and nothing logs or sends it.
public struct DefaultsAlarmIndex: AlarmIndex {
    private static let key = "alarms.scheduleIndex"
    private static let lock = NSLock()
    nonisolated(unsafe) private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private func load() -> [String: [String]] {
        defaults.dictionary(forKey: Self.key) as? [String: [String]] ?? [:]
    }

    public func schedules(of id: UUID) -> Set<ScheduleID>? {
        Self.lock.withLock {
            load()[id.uuidString].map { Set($0.compactMap { UUID(uuidString: $0) }.map { ScheduleID($0) }) }
        }
    }

    public func record(_ id: UUID, schedules: Set<ScheduleID>) {
        Self.lock.withLock {
            var entries = load()
            entries[id.uuidString] = schedules.map(\.rawValue.uuidString)
            defaults.set(entries, forKey: Self.key)
        }
    }

    public func keep(only ids: Set<UUID>) {
        Self.lock.withLock {
            let keep = Set(ids.map(\.uuidString))
            defaults.set(load().filter { keep.contains($0.key) }, forKey: Self.key)
        }
    }

    private static let quietKey = "alarms.cancelWhenQuiet"
    private static let completeKey = "alarms.indexComplete"

    public var isComplete: Bool { defaults.bool(forKey: Self.completeKey) }
    public func markComplete() { defaults.set(true, forKey: Self.completeKey) }

    public func quiet() -> Set<UUID> {
        Self.lock.withLock { Set((defaults.stringArray(forKey: Self.quietKey) ?? []).compactMap { UUID(uuidString: $0) }) }
    }

    public func setQuiet(_ ids: Set<UUID>) {
        Self.lock.withLock { defaults.set(ids.map(\.uuidString), forKey: Self.quietKey) }
    }

    public func forget(_ ids: [UUID]) {
        Self.lock.withLock {
            var entries = load()
            ids.forEach { entries[$0.uuidString] = nil }
            defaults.set(entries, forKey: Self.key)
        }
    }
}
