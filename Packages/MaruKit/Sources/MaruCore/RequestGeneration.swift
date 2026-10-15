import Foundation

/// A durable counter that only grows. The app saves the value before it uses it, so no restart and no change of the clock
/// can give a number twice (D086). All adds run in the app process.
public protocol GenerationCounter: Sendable {
    /// The next number. It is greater than every number that this counter gave before, also in an earlier process.
    func next() -> Int
}

/// A counter in memory, for tests and for a process that has no saved counter.
public final class MemoryGenerationCounter: GenerationCounter, @unchecked Sendable {
    public static let shared = MemoryGenerationCounter()
    private let lock = NSLock()
    private var value: Int

    public init(start: Int = 0) { value = start }

    public func next() -> Int {
        lock.withLock {
            value += 1
            return value
        }
    }
}

/// The one-time move from build 6 (D086). Build 6 gave the system requests with no generation in their identifier.
public protocol LegacyMigration: Sendable {
    var isDone: Bool { get }
    func markDone()
}

/// For a process with no request of build 6.
public struct NoMigration: LegacyMigration {
    public init() {}
    public var isDone: Bool { true }
    public func markDone() {}
}

/// Every request that the app gives the system has a fresh identifier: the base identifier of the plan, a generation from a
/// durable counter, and a short random tail (`<base>|g<counter>r<hex>`). The system never sees an identifier twice (D086).
///
/// A removal names the identifiers that the system held when the app read them. A request that the app adds later has
/// an identifier that no earlier removal can name. So a removal that the system does late, or that a run sends again,
/// can never delete a newer request. The app needs no ledger of open removals, and nothing can block a request.
///
/// Order is the counter only. A request of build 6 has no generation and counts as 0.
///
/// The plan, the tap resolver, and the engines use the base identifier. The generation lives only at the border to the system.
enum RequestGeneration {
    private static let marker = "|g"

    /// The text after the marker: 12 digits, `r`, and 4 hexadecimal digits. `nil` for an identifier with no generation.
    private static func tail(of identifier: String) -> (range: Range<String.Index>, counter: Int)? {
        guard let range = identifier.range(of: marker, options: .backwards) else { return nil }
        let text = identifier[range.upperBound...]
        let parts = text.split(separator: "r", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 12, parts[0].allSatisfy(\.isNumber), parts[1].count == 4,
              parts[1].allSatisfy(\.isHexDigit), let counter = Int(parts[0])
        else { return nil }
        return (range, counter)
    }

    /// The identifier of the plan: the text before the generation. An identifier with no generation is its own base.
    static func base(of identifier: String) -> String {
        tail(of: identifier).map { String(identifier[..<$0.range.lowerBound]) } ?? identifier
    }

    /// The counter of the identifier, or 0 for an identifier of build 6.
    static func counter(of identifier: String) -> Int {
        tail(of: identifier)?.counter ?? 0
    }

    static func isLegacy(_ identifier: String) -> Bool {
        tail(of: identifier) == nil
    }

    /// A new identifier for the base.
    static func fresh(_ base: String, counter: any GenerationCounter) -> String {
        base + marker + String(format: "%012d", counter.next()) + "r" + String(format: "%04x", Int.random(in: 0...0xFFFF))
    }
}

/// The notification system with fresh identifiers (D086). The engines see only base identifiers.
///
/// - A pending read first prunes: for each base, only the request with the highest counter stays, and the others are removed.
///   A stop between an add and its prune can leave two requests of one base until the next run. That window is accepted:
///   a second banner is better than a missing one.
/// - An add gives the request a fresh identifier. After the system holds it, the older requests of the base are removed.
///   If the system does not hold it, the older request stays, and the engine sees a request that it must replace.
///   The count of the system limit is the count of physical requests. When the add would pass 64, the older request of this
///   base goes first. If it still does not fit, the add throws `Full`, and the engine reports the schedule as not set.
/// - A removal removes every request of the bases that it names.
/// - With a migration that is not done, a request of build 6 (no generation) with the prefix of the engine looks like a
///   request with other content, so the engine adds the request with a generation, and the add removes the old one.
struct GenerationCenter: FollowUpCenter {
    struct Full: Error {}
    static let limit = 64

    let base: any ReminderCenter
    /// The same center with the calls of follow-ups. `nil` for a center with series requests only.
    let followUps: (any FollowUpCenter)?
    let counter: any GenerationCounter
    let migration: any LegacyMigration
    /// The identifier prefix of the requests that this engine owns, for the migration.
    let ownPrefix: String

    init(_ center: any ReminderCenter, counter: any GenerationCounter, migration: any LegacyMigration, ownPrefix: String) {
        base = center
        followUps = center as? any FollowUpCenter
        self.counter = counter
        self.migration = migration
        self.ownPrefix = ownPrefix
    }

    func authorization() async -> ReminderAuthorization { await base.authorization() }
    func requestAuthorization() async -> ReminderAuthorization { await base.requestAuthorization() }
    func text(for content: ReminderContent) -> ReminderText { base.text(for: content) }

    /// Removes the older requests of every base. Each run calls it first.
    func prune() async {
        _ = await pendingRequests()
    }

    func pendingRequests() async -> [PendingReminder] {
        let raw = await base.pendingRequests()
        var newest: [String: PendingReminder] = [:]
        var older: [String] = []
        for request in raw.sorted(by: { ($0.identifier) < ($1.identifier) }) {
            let key = RequestGeneration.base(of: request.identifier)
            if let known = newest[key] {
                if RequestGeneration.counter(of: request.identifier) >= RequestGeneration.counter(of: known.identifier) {
                    older.append(known.identifier)
                    newest[key] = request
                } else {
                    older.append(request.identifier)
                }
            } else {
                newest[key] = request
            }
        }
        if !older.isEmpty { await base.remove(identifiers: older) }
        let migrating = !migration.isDone
        return newest.map { key, request in
            if migrating, key.hasPrefix(ownPrefix), RequestGeneration.isLegacy(request.identifier) {
                // A request of build 6: the engine must replace it with a request that has a generation.
                return PendingReminder(identifier: key, userInfo: [:], text: nil, presentation: nil)
            }
            return PendingReminder(
                identifier: key, userInfo: request.userInfo, text: request.text, presentation: request.presentation,
                deliveredAt: request.deliveredAt
            )
        }
    }

    /// Marks the migration as done when the system holds no request of build 6 with the prefix of the engine.
    func finishMigration() async {
        guard !migration.isDone else { return }
        let left = await base.pendingRequests().contains {
            $0.identifier.hasPrefix(ownPrefix) && RequestGeneration.isLegacy($0.identifier)
        }
        if !left { migration.markDone() }
    }

    func add(_ request: ReminderRequest) async throws {
        let fresh = ReminderRequest(
            identifier: RequestGeneration.fresh(request.identifier, counter: counter), trigger: request.trigger,
            content: request.content, userInfo: request.userInfo, fireDate: request.fireDate
        )
        try await replace(base: request.identifier, with: fresh.identifier) { try await base.add(fresh) }
    }

    func add(_ request: FollowUpRequest) async throws {
        guard let followUps else { return }
        let fresh = FollowUpRequest(
            identifier: RequestGeneration.fresh(request.identifier, counter: counter),
            threadIdentifier: request.threadIdentifier, content: request.content, userInfo: request.userInfo,
            fireDate: request.fireDate
        )
        try await replace(base: request.identifier, with: fresh.identifier) { try await followUps.add(fresh) }
    }

    func remove(identifiers: [String]) async {
        let bases = Set(identifiers)
        let held = await base.pendingRequests().map(\.identifier).filter { bases.contains(RequestGeneration.base(of: $0)) }
        if !held.isEmpty { await base.remove(identifiers: held) }
    }

    func delivered() async -> [PendingReminder] { await followUps?.delivered() ?? [] }
    func removeDelivered(identifiers: [String]) async { await followUps?.removeDelivered(identifiers: identifiers) }

    private func replace(base key: String, with fresh: String, add: () async throws -> Void) async throws {
        var raw = await base.pendingRequests().map(\.identifier)
        let before = raw.filter { RequestGeneration.base(of: $0) == key }
        // The system limit counts every physical request. At the limit, the older request of this base goes first.
        if raw.count + 1 > Self.limit {
            guard !before.isEmpty else { throw Full() }
            await base.remove(identifiers: before)
            var checks = 0
            repeat {
                raw = await base.pendingRequests().map(\.identifier)
                checks += 1
                if raw.contains(where: before.contains) { try? await Task.sleep(for: ReminderEngine.removalWait) }
            } while raw.contains(where: before.contains) && checks < ReminderEngine.removalChecks
            if raw.count + 1 > Self.limit { throw Full() }
            try await add()
            return
        }
        try await add()
        guard !before.isEmpty else { return }
        // Remove the older requests only when the system holds the new one. A dropped add keeps the old request.
        let after = await base.pendingRequests().map(\.identifier)
        if after.contains(fresh) { await base.remove(identifiers: before) }
    }
}
