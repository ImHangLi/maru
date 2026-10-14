import Foundation

/// The notification system with the calls that one-time follow-ups need.
public protocol FollowUpCenter: ReminderCenter {
    /// Adds a one-time request. A pending request with the same identifier is replaced.
    func add(_ request: FollowUpRequest) async throws
    /// The notifications that the system shows now.
    func delivered() async -> [PendingReminder]
    /// Removes notifications that the system shows now. Pending requests do not change.
    func removeDelivered(identifiers: [String]) async
}

/// Where the engine reads the follow-ups that the saved plan and the records ask for.
/// Each item carries its own setting (D079).
public protocol FollowUpSource: Sendable {
    /// - Parameter alarmsRing: Alarms can ring now, so the series reminders leave out the items with an alarm.
    ///   Their follow-ups still come (D079).
    func followUpPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarmsRing: Bool
    ) async throws -> FollowUpPlan
}

/// What one refresh found after its changes.
public struct FollowUpOutcome: Hashable, Sendable {
    public let authorization: ReminderAuthorization
    /// The follow-ups that the system holds.
    public let scheduled: Int
    /// Follow-ups of the plan that the system does not hold: no room next to the other requests, not registered,
    /// or blocked by an open removal. A later refresh tries again. The series reminders do not depend on them.
    public let notScheduled: Int
    /// The system still holds a follow-up that the engine removed. Do not show a removal as done (spec 8.1).
    public let removalPending: Bool
}

/// Keeps the optional follow-ups of the next seven days in the system (D021, D039).
///
/// A follow-up is one one-time request for one slot time on one date. A slot time can have more than one.
/// They are set only while a slot at that time has an open occurrence. The series reminders are not changed
/// here (spec 8.1).
///
/// Call `refresh` at these points. Each call recomputes everything, so one more call is never wrong:
/// - after each `ReminderEngine.reconcile`, also at launch and when the app comes back to the foreground
///   (issues #6, #7, #11). The reconcile can remove follow-ups to make room, and this call sets them again;
/// - after each save of an item or a schedule (issue #8);
/// - after each record, skip, or undo, also from a notification action (issue #5, #7). This removes the
///   pending and the delivered follow-ups of a slot time that has no open occurrence now, and the delivered
///   follow-ups that still name a recorded item;
/// - after the user changes the setting of an item, which is a save of the item (D079);
/// - after the device time zone changes.
///
/// A request fires at one instant. A device-following plan gets new instants at the next refresh after
/// a time zone change. Until the app runs, the pending follow-ups keep the instants of the old zone.
/// The follow-up is optional and the series reminders follow the device, so this is accepted.
///
/// When the app does not run for seven days, the last follow-up passes and no new one comes.
/// The series reminders continue. The settings text must state this (D021).
public actor FollowUpEngine {
    /// The most requests that the system holds after a run adds a follow-up: the system limit minus the reserve.
    /// The plan has only the follow-ups that fit next to its series requests. A run of the series engine can add
    /// more new requests than the reserve before it removes the old ones. Then `ReminderEngine` removes
    /// follow-ups first, and the next refresh sets them again (spec 8.4).
    static let limit = ReminderPlan.systemLimit - FollowUpPlan.reserve

    private let source: any FollowUpSource
    private let center: any FollowUpCenter
    private let ledger: any RemovalLedger
    private let privacy: any ReminderPrivacyStore
    /// Whether alarms can ring now, read at each run (D079).
    private let alarmsRing: @Sendable () -> Bool
    private var lastRun: Task<Void, Never>?
    /// Follow-up identifiers that the engine removed and that the system still held at the last read.
    /// The ledger has a copy. The rule is the one of `ReminderEngine`: an identifier is not added again
    /// before its removal is confirmed, so a late removal cannot delete the new request.
    private var unremoved: Set<String>

    /// - Parameter ledger: A ledger of its own. It must not share its storage with the ledger of `ReminderEngine`.
    public init(
        source: any FollowUpSource,
        center: any FollowUpCenter,
        ledger: any RemovalLedger,
        privacy: any ReminderPrivacyStore,
        alarmsRing: @escaping @Sendable () -> Bool = { false }
    ) {
        self.source = source
        self.center = center
        self.ledger = ledger
        self.privacy = privacy
        self.alarmsRing = alarmsRing
        unremoved = ledger.load()
    }

    /// Makes the pending and the delivered follow-ups agree with the plan, the records, and the setting of each item.
    ///
    /// Runs do not overlap, as in `ReminderEngine`. An error from the source stops the run before it adds
    /// a request. The run never asks for the notification permission. The series engine does that.
    public func refresh(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> FollowUpOutcome {
        let previous = lastRun
        let run = Task {
            await previous?.value
            return try await self.run(at: now, deviceTimeZone: deviceTimeZone)
        }
        lastRun = Task { _ = try? await run.value }
        return try await run.value
    }

    private func run(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> FollowUpOutcome {
        let privacy = privacy.load()
        let plan = try await source.followUpPlan(
            privacy: privacy, at: now, deviceTimeZone: deviceTimeZone, alarmsRing: alarmsRing()
        )
        let authorization = await center.authorization()
        // Remove before add, the other order from `ReminderEngine`. A moved slot time or a new setting changes
        // every follow-up of the next seven days, and the old and the new requests together can pass the system limit.
        // Then the system can reject or drop a wanted request, also a series request.
        let before = await pendingAfterRemoval()
        let kept = Dictionary(
            Self.fitting(plan.requests, pending: before).map { ($0.identifier, $0.userInfo) },
            uniquingKeysWith: { first, _ in first }
        )
        await remove(Self.followUps(before).keys.filter { kept[$0] == nil })
        let pending = await pendingAfterRemoval()
        if authorization == .authorized {
            let current = Self.followUps(pending)
            // A request that the system still holds, also one with an open removal, takes room.
            var room = max(0, Self.limit - pending.count)
            for request in Self.fitting(plan.requests, pending: pending)
            where !isCurrent(current[request.identifier], request) && !unremoved.contains(request.identifier) {
                // A request with the same identifier replaces the pending one and takes no more room.
                if current[request.identifier] == nil {
                    guard room > 0 else { continue }
                    room -= 1
                }
                // The read below is the result. The system can also drop a request with no error.
                try? await center.add(request)
            }
        }
        // A delivered follow-up keeps its text. So one that names a recorded, renamed, or archived item goes (D029).
        // A delivered first reminder stays: it is true for its time, and Today shows the records.
        // The exception is the privacy setting: with names hidden, a delivered first reminder that shows names goes.
        let neutral = center.text(for: ReminderContent(kind: .due, names: nil))
        let delivered = await center.delivered().filter { shown in
            if shown.identifier.hasPrefix(FollowUpRequest.identifierPrefix) {
                return shown.text != plan.open[shown.identifier].map(center.text(for:))
            }
            return privacy == .hideNames && shown.identifier.hasPrefix(ReminderSeries.identifierPrefix)
                && shown.text != neutral
        }.map(\.identifier)
        if !delivered.isEmpty { await center.removeDelivered(identifiers: delivered) }
        let held = Self.followUps(await pendingAfterRemoval())
        let scheduled = authorization == .authorized
            ? plan.requests.filter { isCurrent(held[$0.identifier], $0) }.count
            : 0
        return FollowUpOutcome(
            authorization: authorization,
            scheduled: scheduled,
            notScheduled: plan.requests.count - scheduled,
            removalPending: !unremoved.isEmpty
        )
    }

    /// The nearest requests that fit next to the other requests of the app. The series requests come first
    /// (spec 8.4): the follow-ups never get more than `limit` minus every pending request that is not a follow-up.
    /// The plan leaves this room, so the cut is only for a request that the plan does not know.
    private static func fitting(_ requests: [FollowUpRequest], pending: [PendingReminder]) -> ArraySlice<FollowUpRequest> {
        let others = pending.count - followUps(pending).count
        return requests.prefix(max(0, limit - others))
    }

    /// The pending follow-ups by identifier.
    private static func followUps(_ pending: [PendingReminder]) -> [String: PendingReminder] {
        Dictionary(
            pending.filter { $0.identifier.hasPrefix(FollowUpRequest.identifierPrefix) }.map { ($0.identifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// A pending follow-up is current when it has the `userInfo`, the text, and the action of the request, and the
    /// time-sensitive level (D029, D034, D062).
    /// The fire instant is in `userInfo`. The text changes with a record, a rename, the setting, or the language.
    private func isCurrent(_ held: PendingReminder?, _ request: FollowUpRequest) -> Bool {
        guard let held else { return false }
        return held.userInfo == request.userInfo && held.text == center.text(for: request.content)
            && held.hasTakenAction == request.content.hasTakenAction && held.isTimeSensitive
    }

    /// The same rule as `ReminderEngine`: each identifier has at most one open removal, and the ledger
    /// gets it before the call.
    private func remove(_ identifiers: [String]) async {
        let new = identifiers.filter { !unremoved.contains($0) }
        guard !new.isEmpty else { return }
        unremoved.formUnion(new)
        ledger.save(unremoved)
        await center.remove(identifiers: new)
    }

    /// Reads the pending requests until the system holds none that the engine removed, at most
    /// `ReminderEngine.removalChecks` times.
    private func pendingAfterRemoval() async -> [PendingReminder] {
        var checks = 0
        while true {
            let pending = await center.pendingRequests()
            checks += 1
            let before = unremoved
            unremoved.formIntersection(pending.map(\.identifier))
            if unremoved != before { ledger.save(unremoved) }
            if unremoved.isEmpty || checks == ReminderEngine.removalChecks { return pending }
            try? await Task.sleep(for: ReminderEngine.removalWait)
        }
    }
}
