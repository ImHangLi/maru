import Foundation

/// The notification permission of the app, as the engine needs it.
public enum ReminderAuthorization: Hashable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// A request that the system holds for a later delivery.
public struct PendingReminder: Hashable, Sendable {
    public let identifier: String
    public let userInfo: [String: String]
    /// The text that the system shows. It can name items, so it stays in memory and is never logged (spec 10).
    public let text: ReminderText?
    /// The request has the category of the "Taken" action (D034).
    public let hasTakenAction: Bool
    /// The request has the time-sensitive level (D062). A request from a build before D062 has the default
    /// level, so the engines replace it.
    public let isTimeSensitive: Bool
    /// When the system delivered the notification. `nil` for a pending request.
    public let deliveredAt: Date?

    public init(
        identifier: String, userInfo: [String: String], text: ReminderText? = nil, hasTakenAction: Bool = false,
        isTimeSensitive: Bool = true, deliveredAt: Date? = nil
    ) {
        self.deliveredAt = deliveredAt
        self.identifier = identifier
        self.userInfo = userInfo
        self.text = text
        self.hasTakenAction = hasTakenAction
        self.isTimeSensitive = isTimeSensitive
    }
}

/// The notification system. The rules of the engine use only this protocol, so they run without UserNotifications.
public protocol ReminderCenter: Sendable {
    func authorization() async -> ReminderAuthorization
    /// Shows the permission prompt of the system and returns the answer. The system shows the prompt one time only.
    func requestAuthorization() async -> ReminderAuthorization
    /// Every pending request of the app, also the ones that the engine does not own.
    func pendingRequests() async -> [PendingReminder]
    /// Adds a request. A pending request with the same identifier is replaced.
    func add(_ request: ReminderRequest) async throws
    /// Asks the system to remove the requests. The system can remove them after the call returns,
    /// so the engine reads the pending requests to see that they are gone.
    func remove(identifiers: [String]) async
    /// The text that `add` gives the system for this content, in the language of now (D029).
    /// The engines compare it with the text of the pending request.
    func text(for content: ReminderContent) -> ReminderText
}

/// Where the engine keeps the identifiers of removals that the system did not complete yet.
/// It must keep them after the app stops, so that the next start does not take such a request as current.
public protocol RemovalLedger: Sendable {
    func load() -> Set<String>
    func save(_ identifiers: Set<String>)
}

/// Where the engine reads the saved plan.
public protocol ReminderPlanSource: Sendable {
    /// - Parameter alarms: Which items an alarm covers now, so the plan leaves them out (D079).
    func reminderPlan(
        at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover
    ) async throws -> ReminderPlan
}

/// Where the setting "Show Names in Reminders" is kept. It is a preference, so it is not in the health database (D014, D029).
public protocol ReminderPrivacyStore: Sendable {
    /// A new install has no value, so the reminders name the items.
    func load() -> ReminderPrivacy
    func save(_ privacy: ReminderPrivacy)
}

/// What a run must change in the system to make the pending requests the wanted ones.
///
/// A pending request is current when it has the identifier, the `userInfo`, the text, and the action of a wanted
/// request. The identifier gives the trigger, the revision in `userInfo` gives the members, and the text gives
/// the names, the setting, and the language (D029). So a second run with the same plan changes nothing,
/// and a rename replaces only the requests that name the item. A request from before the "Taken" action
/// has no category, so the first run after the update replaces it (D034).
public struct ReminderChanges: Hashable, Sendable {
    /// Wanted requests that are not pending, or that are pending with another revision, text, or action.
    /// An add with the identifier of a pending request replaces it.
    public let add: [ReminderRequest]
    /// The identifiers of pending series requests that the plan does not have. A request with another
    /// kind of identifier is not a series request, and it stays.
    public let remove: [String]

    /// - Parameter text: The text of a content in the language of now, from `ReminderCenter.text(for:)`.
    public init(wanted: [ReminderRequest], pending: [PendingReminder], text: (ReminderContent) -> ReminderText) {
        let current = Dictionary(pending.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
        let identifiers = Set(wanted.map(\.identifier))
        add = wanted.filter { request in
            guard let held = current[request.identifier] else { return true }
            return held.userInfo != request.userInfo || held.text != text(request.content)
                || held.hasTakenAction != request.content.hasTakenAction || !held.isTimeSensitive
        }
        remove = pending.map(\.identifier).filter {
            $0.hasPrefix(ReminderSeries.identifierPrefix) && !identifiers.contains($0)
        }
    }
}

/// The reminder of one schedule, as the system has it now. A screen shows this state, and not the saved plan.
public enum ReminderState: Hashable, Sendable {
    /// The schedule asks for no reminder: the reminders are off, or the item is archived (T07, T08).
    case off
    /// The system holds every request of the schedule.
    case scheduled
    /// The plan is saved, and the reminder is not set. Do not show a success for it (spec 8.1).
    case notSet(ReminderProblem)
    /// The system did not finish a removal in the time of the run. A request that the plan does not have
    /// can still remind, and a request with the same identifier can still go away. So the run confirms
    /// no "off" and no "scheduled". A request names no schedule, so every schedule that is not `.notSet`
    /// gets this state. Show that the reminder is not confirmed, and run again later.
    case removalPending
}

/// What one run found after its changes (spec 8.1, 8.5, T03).
public struct ReminderOutcome: Hashable, Sendable {
    public let authorization: ReminderAuthorization
    /// Every schedule of the plan. An item with no schedule has no entry.
    public let schedules: [ScheduleID: ReminderState]
    /// The run did not confirm a removal. A schedule that the plan no longer has, for example of a deleted
    /// item, has no entry in `schedules`, so this value says whether its requests are gone.
    public let removalPending: Bool

    /// - Parameters:
    ///   - unregistered: The identifiers of wanted requests that the system does not hold.
    ///   - removalPending: The system still holds a request that the engine removed.
    init(plan: ReminderPlan, authorization: ReminderAuthorization, unregistered: Set<String>, removalPending: Bool) {
        self.authorization = authorization
        self.removalPending = removalPending
        schedules = plan.needs.mapValues { need in
            switch (need, authorization) {
            case (.nothing, _): removalPending ? .removalPending : .off
            case let (.blocked(problem), _): .notSet(problem)
            // The alarm does not need the notification permission.
            case (.alarm, _): removalPending ? .removalPending : .scheduled
            case (.requests, .notDetermined): .notSet(.permissionNotAsked)
            case (.requests, .denied): .notSet(.permissionDenied)
            case let (.requests(identifiers), .authorized):
                if !identifiers.isDisjoint(with: unregistered) {
                    .notSet(.notRegistered)
                } else {
                    removalPending ? .removalPending : .scheduled
                }
            }
        }
    }
}

/// Makes the pending requests of the system agree with the saved plan (spec 8.1, 8.5).
///
/// The database and the notification system do not commit together. So the plan is saved first, and a run
/// follows: after each save, at each launch, and when the app comes back to the foreground. A run compares
/// the plan with the pending requests and changes only the difference. A run that stops early leaves
/// a difference, and the next run removes it. The only state on disk is the set of open removals in the `RemovalLedger`.
///
/// A repeating request needs no later run. A dated request of a plan that repeats every second day does:
/// each run adds the requests of the new due dates, as `FollowUpEngine` does for the follow-ups (D036).
public actor ReminderEngine {
    /// How many times a run reads the pending requests to see that a removal is complete.
    public static let removalChecks = 10
    /// The wait between two of these reads. The system removes a request a short time after the call,
    /// so ten reads in about half a second are enough, and a save does not wait long for its outcome.
    public static let removalWait = Duration.milliseconds(50)

    private let source: any ReminderPlanSource
    private let center: any ReminderCenter
    private let ledger: any RemovalLedger
    private let privacy: any ReminderPrivacyStore
    private let zoneRecord: DefaultsTimeZoneRecord?
    /// Which items an alarm covers now, read at each run (D079).
    private let alarms: @Sendable () -> AlarmCover
    /// The clock at the time of the call. A run reads it when it reads the pending requests, after every wait.
    private let clock: @Sendable () -> Date
    private var lastRun: Task<Void, Never>?
    /// The identifiers that the engine removed and that the system still held at the last read.
    /// The ledger has a copy, so a new start of the app also waits for a removal of the process before it.
    private var unremoved: Set<String>

    /// - Parameters:
    ///   - zoneRecord: Gets the device time zone of each successful run, for the notification tap (spec 8.3).
    ///   - alarms: Which items an alarm covers. They have no notification (D079).
    ///   - clock: The clock of the system. A run uses it only to see that the time of a dated request passed.
    public init(
        source: any ReminderPlanSource,
        center: any ReminderCenter,
        ledger: any RemovalLedger,
        privacy: any ReminderPrivacyStore,
        zoneRecord: DefaultsTimeZoneRecord? = nil,
        alarms: @escaping @Sendable () -> AlarmCover = { .none },
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.source = source
        self.center = center
        self.ledger = ledger
        self.privacy = privacy
        self.zoneRecord = zoneRecord
        self.alarms = alarms
        self.clock = clock
        unremoved = ledger.load()
    }

    /// Runs one reconciliation and returns the state after it.
    ///
    /// Runs do not overlap. A run starts after the run before it ends, and then it reads the plan. If two runs
    /// read and wrote at the same time, the one with the older plan could remove a request of the newer plan.
    ///
    /// An error from the plan source stops the run before it changes a request. A plan that the engine
    /// cannot read is not an empty plan.
    ///
    /// A run ends after the system no longer holds the requests that the run removed. The system removes
    /// a request some time after the call. If a run ended before that, the next run could keep a request
    /// that then goes away. When the removal is not complete after `removalChecks` reads, the outcome is
    /// `.removalPending`, and the next run waits for the removal before it changes a request.
    ///
    /// - Parameters:
    ///   - now: The clock of the run. The plan uses the schedule versions that are in force on this date.
    ///   - deviceTimeZone: The time zone of the device, for the schedule versions that follow it.
    ///   - mayAskForPermission: Pass `true` only after the user confirms a save. The engine then
    ///     shows the permission prompt, if the plan has a reminder and the user did not answer before (spec 2.2).
    public func reconcile(
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        mayAskForPermission: Bool = false
    ) async throws -> ReminderOutcome {
        let previous = lastRun
        let run = Task {
            await previous?.value
            let outcome = try await self.run(at: now, deviceTimeZone: deviceTimeZone, mayAskForPermission: mayAskForPermission)
            self.zoneRecord?.observe(deviceTimeZone, at: now)
            return outcome
        }
        lastRun = Task { _ = try? await run.value }
        return try await run.value
    }

    private func run(at now: Date, deviceTimeZone: NamedTimeZone, mayAskForPermission: Bool) async throws -> ReminderOutcome {
        let plan = try await source.reminderPlan(
            at: now, deviceTimeZone: deviceTimeZone, privacy: privacy.load(), alarms: alarms()
        )
        let wanted = plan.requests
        var authorization = await center.authorization()
        if authorization == .notDetermined, mayAskForPermission, !wanted.isEmpty {
            authorization = await center.requestAuthorization()
        }
        // A removal of a run before this one can still be open. This read waits for it first.
        let pending = await pendingAfterRemoval()
        let changes = ReminderChanges(wanted: wanted, pending: pending, text: center.text(for:))
        // The system rejects a new request while notifications are off. The removals still run,
        // so a paused schedule does not remind again when the user turns notifications on.
        guard authorization == .authorized else {
            await remove(changes.remove)
            _ = await pendingAfterRemoval()
            return ReminderOutcome(
                plan: plan, authorization: authorization, unregistered: [], removalPending: !unremoved.isEmpty
            )
        }
        // Add before remove. If the app stops between the two, the user gets one reminder too many
        // until the next run, and not one too few.
        // An open removal can still take a request with its identifier, so the run does not add that request.
        let additions = changes.add.filter { !unremoved.contains($0.identifier) }
        let (fitting, removedFirst) = await makeRoom(for: additions, pending: pending, obsolete: changes.remove)
        for request in fitting {
            // The second read below is the result. The system can also drop a request with no error.
            try? await center.add(request)
        }
        if !removedFirst { await remove(changes.remove) }
        // An addition with no room waits for the next run. Its schedule is not confirmed, and it is not a failure.
        let deferred = Set(additions.map(\.identifier)).subtracting(fitting.map(\.identifier))
        // A dated request whose time passed is not pending, because the system delivered it (D036).
        // The clock is read at the read of the pending requests, and not taken from `now`: the caller can
        // wait in a queue before the run, and the run waits for the system. A request whose time is
        // still to come must be pending: a time that is near does not show a delivery.
        var pendingNow = await pendingAfterRemoval()
        // A replacement that did not land leaves the old request, with its old names. A request that names an archived,
        // deleted, or recorded item must not stay (D084). The run first adds the replacement again. When the old request
        // is still there, the run removes it through the ledger and, after the system confirms the removal, adds the
        // replacement in the same run. So the dose time does not pass with no reminder. An identifier whose removal
        // the system did not confirm stays blocked, as for every removal.
        func staleRequests() -> [ReminderRequest] {
            let held = Dictionary(pendingNow.map { ($0.identifier, $0) }, uniquingKeysWith: { first, _ in first })
            return wanted.filter { request in
                guard let old = held[request.identifier] else { return false }
                return old.userInfo != request.userInfo || old.text != center.text(for: request.content)
            }
        }
        var stale = staleRequests()
        if !stale.isEmpty {
            // An add with the identifier of a pending request replaces it and takes no room.
            for request in stale where !unremoved.contains(request.identifier) { try? await center.add(request) }
            pendingNow = await pendingAfterRemoval()
            stale = staleRequests()
        }
        if !stale.isEmpty {
            await remove(stale.map(\.identifier))
            pendingNow = await pendingAfterRemoval()
            let held = Set(pendingNow.map(\.identifier))
            var room = ReminderPlan.systemLimit - pendingNow.count
            let now = clock()
            for request in stale
            where !unremoved.contains(request.identifier) && !held.contains(request.identifier)
                && (request.fireDate.map { $0 > now } ?? true) && room > 0 {
                room -= 1
                try? await center.add(request)
            }
            pendingNow = await pendingAfterRemoval()
        }
        let readAt = clock()
        let open = ReminderChanges(wanted: wanted, pending: pendingNow, text: center.text(for:)).add
            .filter { request in request.fireDate.map { $0 > readAt } ?? true }
        return ReminderOutcome(
            plan: plan,
            authorization: authorization,
            unregistered: Set(open.map(\.identifier)).subtracting(deferred),
            removalPending: !unremoved.isEmpty || !deferred.isEmpty
        )
    }

    /// Makes room in the system for the additions when the pending requests and the additions together
    /// pass `ReminderPlan.systemLimit`. Over the limit, the system can drop a wanted request (spec 8.4).
    ///
    /// Every pending request counts, also a follow-up and a request with an open removal. An addition with
    /// the identifier of a pending request replaces it and takes no room. The steps, until there is room:
    /// 1. Remove the latest follow-ups. They are optional, and `FollowUpEngine.refresh` sets them again.
    ///    The app calls it after each `reconcile` (issues #7, #11).
    /// 2. Remove the obsolete series requests, with a confirmed removal. If the app stops after this step,
    ///    the user gets one reminder too few until the next run. That is better than a dropped request.
    /// 3. Read the pending requests again. A removal that the system did not complete still takes room.
    ///    Only the additions that fit stay, in the order of the plan. The next run adds the others.
    /// With room, the run keeps the order add before remove.
    ///
    /// Returns the additions to make, and `true` when it removed the obsolete series requests already.
    private func makeRoom(
        for additions: [ReminderRequest], pending: [PendingReminder], obsolete: [String]
    ) async -> (fitting: [ReminderRequest], removedFirst: Bool) {
        let held = Set(pending.map(\.identifier))
        let new = additions.filter { !held.contains($0.identifier) }.count
        var excess = pending.count + new - ReminderPlan.systemLimit
        guard excess > 0 else { return (additions, false) }
        let followUps = pending
            .filter { $0.identifier.hasPrefix(FollowUpRequest.identifierPrefix) }
            .sorted { ($0.userInfo[FollowUpRequest.fireTimeKey] ?? "") > ($1.userInfo[FollowUpRequest.fireTimeKey] ?? "") }
            .prefix(excess)
            .map(\.identifier)
        if !followUps.isEmpty {
            excess = await pendingCount(afterRemoving: followUps) + new - ReminderPlan.systemLimit
        }
        guard excess > 0 else { return (additions, false) }
        await remove(obsolete)
        let live = await pendingAfterRemoval()
        let liveHeld = Set(live.map(\.identifier))
        var room = ReminderPlan.systemLimit - live.count
        let fitting = additions.filter { request in
            // A replacement takes no room.
            if liveHeld.contains(request.identifier) { return true }
            guard room > 0 else { return false }
            room -= 1
            return true
        }
        return (fitting, true)
    }

    /// Removes follow-ups and reads the pending requests until the system holds none of them, at most
    /// `removalChecks` times. They stay out of the ledger of this engine. `FollowUpEngine` adds the same
    /// identifiers again, so an entry here would never close. A late removal can then delete a new follow-up,
    /// and the next refresh sets it again.
    private func pendingCount(afterRemoving followUps: [String]) async -> Int {
        await center.remove(identifiers: followUps)
        var checks = 0
        while true {
            let pending = await center.pendingRequests()
            checks += 1
            if Set(pending.map(\.identifier)).isDisjoint(with: followUps) || checks == Self.removalChecks {
                return pending.count
            }
            try? await Task.sleep(for: Self.removalWait)
        }
    }

    /// Asks the system to remove the identifiers that have no open removal.
    ///
    /// An identifier of an open removal is not sent again. With two removals open, the first one could complete,
    /// a run could then add the request again, and the second removal could delete it. So each identifier has
    /// at most one open removal, and its disappearance from the pending requests confirms that removal.
    /// The ledger gets the identifiers before the call, so a stop of the app after the call does not lose them.
    private func remove(_ identifiers: [String]) async {
        let new = identifiers.filter { !unremoved.contains($0) }
        if !new.isEmpty {
            unremoved.formUnion(new)
            ledger.save(unremoved)
        }
        await center.remove(identifiers: new)
    }

    /// Reads the pending requests until the system holds none that the engine removed, at most
    /// `removalChecks` times. The identifiers that the last read still has stay in `unremoved`.
    private func pendingAfterRemoval() async -> [PendingReminder] {
        var checks = 0
        while true {
            let pending = await center.pendingRequests()
            checks += 1
            let before = unremoved
            unremoved.formIntersection(pending.map(\.identifier))
            if unremoved != before { ledger.save(unremoved) }
            if unremoved.isEmpty || checks == Self.removalChecks { return pending }
            try? await Task.sleep(for: Self.removalWait)
        }
    }
}
