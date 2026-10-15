import Foundation

/// Every request that the app gives the system has a fresh identifier: the base identifier of the plan and a generation
/// (`<base>|g<number>`). The system never sees an identifier twice (D086).
///
/// A removal names the identifiers that the system held when the app read them. A request that the app adds later has
/// an identifier that no earlier removal can name. So a removal that the system does late, or that a run sends again,
/// can never delete a newer request. The app needs no ledger of open removals, and nothing can block a request.
///
/// The plan, the tap resolver, and the engines use the base identifier. The generation lives only at the border to the system.
enum RequestGeneration {
    private static let marker = "|g"
    private static let lock = NSLock()
    nonisolated(unsafe) private static var last = 0

    /// The identifier of the plan: the text before the generation. An identifier with no generation is its own base.
    static func base(of identifier: String) -> String {
        guard let range = identifier.range(of: marker, options: .backwards) else { return identifier }
        let tail = identifier[range.upperBound...]
        return tail.count >= 6 && tail.allSatisfy(\.isNumber) ? String(identifier[..<range.lowerBound]) : identifier
    }

    /// A new identifier for the base. The numbers only grow in one process, and they start from the clock, so two
    /// processes do not repeat a number either.
    static func fresh(_ base: String) -> String {
        let number = lock.withLock { () -> Int in
            last = max(last + 1, Int(Date().timeIntervalSince1970 * 1000) * 1000)
            return last
        }
        return base + marker + String(number)
    }
}

/// The notification system with fresh identifiers (D086). The engines see only base identifiers.
///
/// - A pending read gives one request for each base. A base that the system holds twice, for example after a stop
///   between an add and a removal, shows its newest request, and the older ones are removed.
/// - An add gives the request a fresh identifier. After the system holds it, the older requests of the base are removed.
///   If the system does not hold it, the older request stays, and the engine sees a request that it must replace.
/// - A removal removes every request of the bases that it names.
struct GenerationCenter: FollowUpCenter {
    let base: any ReminderCenter
    /// The same center with the calls of follow-ups. `nil` for a center with series requests only.
    let followUps: (any FollowUpCenter)?

    init(_ center: any ReminderCenter) {
        base = center
        followUps = center as? any FollowUpCenter
    }

    func authorization() async -> ReminderAuthorization { await base.authorization() }
    func requestAuthorization() async -> ReminderAuthorization { await base.requestAuthorization() }
    func text(for content: ReminderContent) -> ReminderText { base.text(for: content) }

    func pendingRequests() async -> [PendingReminder] {
        let raw = await base.pendingRequests()
        var newest: [String: PendingReminder] = [:]
        var older: [String] = []
        for request in raw.sorted(by: { $0.identifier < $1.identifier }) {
            let key = RequestGeneration.base(of: request.identifier)
            if let known = newest[key] { older.append(known.identifier) }
            newest[key] = request
        }
        if !older.isEmpty { await base.remove(identifiers: older) }
        return newest.map { key, request in
            PendingReminder(
                identifier: key, userInfo: request.userInfo, text: request.text, hasTakenAction: request.hasTakenAction,
                isTimeSensitive: request.isTimeSensitive, deliveredAt: request.deliveredAt
            )
        }
    }

    func add(_ request: ReminderRequest) async throws {
        let fresh = ReminderRequest(
            identifier: RequestGeneration.fresh(request.identifier), trigger: request.trigger, content: request.content,
            userInfo: request.userInfo, fireDate: request.fireDate
        )
        try await replace(base: request.identifier, with: fresh.identifier) { try await base.add(fresh) }
    }

    func add(_ request: FollowUpRequest) async throws {
        guard let followUps else { return }
        let fresh = FollowUpRequest(
            identifier: RequestGeneration.fresh(request.identifier), threadIdentifier: request.threadIdentifier,
            content: request.content, userInfo: request.userInfo, fireDate: request.fireDate
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
        let before = await base.pendingRequests().map(\.identifier).filter { RequestGeneration.base(of: $0) == key }
        try await add()
        guard !before.isEmpty else { return }
        // Remove the older requests only when the system holds the new one. A dropped add keeps the old request.
        let after = await base.pendingRequests().map(\.identifier)
        if after.contains(fresh) { await base.remove(identifiers: before) }
    }
}
