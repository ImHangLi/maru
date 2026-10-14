import Foundation

/// Which items an alarm covers now (D079). A covered item gets no notification at its dose time.
/// An item is not covered when alarms cannot ring (before iOS 26, or no permission), or when the system
/// did not schedule one of its alarms. It then gets its normal reminder, so a failed alarm loses no reminder.
public struct AlarmCover: Sendable, Equatable {
    public var rings: Bool
    /// The items with an alarm that the last run did not schedule.
    public var failed: Set<ItemID>

    public init(rings: Bool, failed: Set<ItemID> = []) {
        self.rings = rings
        self.failed = failed
    }

    public static let none = AlarmCover(rings: false)

    func covers(_ item: Item) -> Bool {
        rings && item.alarm && !failed.contains(item.id)
    }
}

/// One alarm that rings at the time of a dose (D079). It is one alarm for one slot time on one date.
/// The items with an alarm and an open dose at that time share it.
public struct AlarmRequest: Hashable, Sendable {
    /// The identifier of the alarm in the system. It comes from the group, the items, and the names, so a change
    /// of the items or of a name gives another identifier, and the engine replaces the alarm.
    public let id: UUID
    public let fireDate: Date
    /// The items with an open dose at this time that the alarm stands for.
    public let itemIDs: [ItemID]
    /// The names of the items, in the order of the schedules. `nil` when the user hides the names (D029).
    public let names: [String]?
    /// What the "Taken" button needs, when the alarm stands for exactly one item that is alone at its time.
    /// The keys are the ones of a follow-up (D034), so the same checks run. `nil`: the button opens the app.
    public let taken: [String: String]?
}

/// The alarms that the saved plan, the records, and the items ask for (D079).
///
/// An alarm comes for a slot time with an open dose of an item with `alarm`, in the next seven days.
/// A dose that has a record gets none, so a record cancels its alarm at the next run (D047).
/// The app sets the alarms again at each run, as it does for the follow-ups. When the app does not run for
/// seven days, the last alarm passes and no new one comes.
///
/// It is a value of its inputs and reads no system state.
public struct AlarmPlan: Hashable, Sendable {
    /// The most alarms that the plan holds, the nearest first. The system documents no limit,
    /// so this is a safe size and not a measured one.
    public static let limit = 64

    /// The alarms, nearest first.
    public let requests: [AlarmRequest]

    /// - Parameter reminders: The series plan of the same read, built with `alarmsRing`. Only a schedule
    ///   with the need `.alarm` can ring, so a paused, archived, or ended schedule gets none.
    public init(
        reminders: ReminderPlan,
        items: [Item],
        schedules: [Schedule],
        stored: [StoredOccurrence],
        closed: Set<OccurrenceKey>,
        now: Date,
        deviceTimeZone: NamedTimeZone,
        privacy: ReminderPrivacy = .showNames
    ) {
        let ringing = Set(schedules.filter { reminders.needs[$0.id] == .alarm }.map(\.itemID))
        guard !ringing.isEmpty else {
            requests = []
            return
        }
        // Every schedule that reminds counts for the groups: a dose of another item at the same time means that
        // the "Taken" button records nothing (D034).
        let reminding = schedules.filter {
            switch reminders.needs[$0.id] {
            case .requests?, .alarm?: true
            default: false
            }
        }
        let groups = DoseGroups(
            reminding: reminding, items: items, stored: stored, closed: closed, now: now, deviceTimeZone: deviceTimeZone
        )
        let end = now.addingTimeInterval(Double(FollowUpPlan.days) * 86_400)
        var found: [AlarmRequest] = []
        for (group, instant) in groups.slotInstants where instant > now && instant <= end {
            let open = groups.orderedOpenItems(of: group).filter { ringing.contains($0.itemID) }
            guard !open.isEmpty else { continue }
            let names = privacy == .showNames ? open.compactMap(\.name) : []
            var taken: [String: String]?
            if open.count == 1, let single = groups.single(of: group), single.itemID == open[0].itemID {
                taken = [
                    ReminderRequest.seriesIDKey: group.seriesID,
                    FollowUpRequest.plannedDateKey: group.dateText,
                    FollowUpRequest.fireTimeKey: instant.formatted(.iso8601),
                    FollowUpRequest.itemIDKey: single.itemID.rawValue.uuidString,
                    FollowUpRequest.scheduleVersionIDKey: single.versionID.rawValue.uuidString,
                ]
            }
            let key = ([group.identifier] + open.map { $0.itemID.rawValue.uuidString } + names + [taken == nil ? "open" : "taken"])
                .joined(separator: "\n")
            found.append(
                AlarmRequest(
                    id: Self.identifier(of: key), fireDate: instant, itemIDs: open.map(\.itemID),
                    names: names.isEmpty ? nil : names, taken: taken
                )
            )
        }
        requests = Array(found.sorted { ($0.fireDate, $0.id.uuidString) < ($1.fireDate, $1.id.uuidString) }.prefix(Self.limit))
    }

    /// A stable identifier from a text: two FNV-1a hashes with two starts make 16 bytes. It tells two texts apart
    /// and protects nothing.
    static func identifier(of text: String) -> UUID {
        func hash(_ start: UInt64) -> [UInt8] {
            let value = text.utf8.reduce(start) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
            return (0..<8).map { UInt8(truncatingIfNeeded: value >> UInt64(56 - 8 * $0)) }
        }
        let bytes = hash(0xcbf2_9ce4_8422_2325) + hash(0x8422_2325_cbf2_9ce4)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

/// The alarm system. The rules of the engine use only this protocol, so they run without AlarmKit (D079).
public protocol AlarmCenter: Sendable {
    /// The identifiers of the alarms that wait for their time. An alarm that rings now is not in the set,
    /// so a run never stops a ringing alarm.
    func waiting() async -> Set<UUID>
    /// Schedules the alarm. The system holds it until its time.
    func schedule(_ request: AlarmRequest) async throws
    /// Cancels the alarms with these identifiers.
    func cancel(_ ids: [UUID]) async
}

/// Where the engine reads the alarms that the saved plan and the records ask for.
public protocol AlarmSource: Sendable {
    /// - Parameter alarms: With `rings` false, the plan has no alarm.
    func alarmPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover
    ) async throws -> AlarmPlan
}

/// Keeps the alarms of the next seven days in the system (D079).
///
/// The app calls `refresh` after each run of the reminder engine, so after each save of an item, each record,
/// skip, or undo, at launch, and when the app comes back to the front. Each call recomputes everything.
/// It cancels a waiting alarm that the plan does not have, and it schedules the alarms that the system lacks.
/// The identifier of an alarm holds its content, so a waiting alarm with a plan identifier is current.
/// The notification queue of the app serializes the runs.
public struct AlarmEngine: Sendable {
    private let source: any AlarmSource
    private let center: any AlarmCenter
    private let privacy: any ReminderPrivacyStore
    private let alarmsRing: @Sendable () -> Bool

    public init(
        source: any AlarmSource,
        center: any AlarmCenter,
        privacy: any ReminderPrivacyStore,
        alarmsRing: @escaping @Sendable () -> Bool
    ) {
        self.source = source
        self.center = center
        self.privacy = privacy
        self.alarmsRing = alarmsRing
    }

    /// An error from the source stops the run before it changes an alarm. A failed schedule leaves
    /// the alarm out until the next run.
    ///
    /// - Returns: The items with an alarm that the system did not schedule. The notification engines give
    ///   them their normal reminder in the same run (D079). The notification of an item is one repeating request,
    ///   so coverage is for the whole item and not for one dose. When one alarm of an item fails, the run cancels
    ///   the other alarms of that item and of every item that shares an alarm with it. So no dose gets an alarm and
    ///   a banner together.
    public func refresh(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> Set<ItemID> {
        let plan = try await source.alarmPlan(
            privacy: privacy.load(), at: now, deviceTimeZone: deviceTimeZone, alarms: AlarmCover(rings: alarmsRing())
        )
        let waiting = await center.waiting()
        let wanted = Set(plan.requests.map(\.id))
        let obsolete = waiting.subtracting(wanted)
        if !obsolete.isEmpty { await center.cancel(Array(obsolete)) }
        var failed = Set<ItemID>()
        /// The alarms that the system holds after this run. A ringing alarm is not in `waiting` and stays.
        var held = waiting.intersection(wanted)
        for request in plan.requests where !waiting.contains(request.id) {
            do {
                try await center.schedule(request)
                held.insert(request.id)
            } catch {
                failed.formUnion(request.itemIDs)
            }
        }
        // Cancel each held alarm of a failed item, until no new item fails with it.
        var changed = !failed.isEmpty
        while changed {
            changed = false
            for request in plan.requests where held.contains(request.id) && !failed.isDisjoint(with: request.itemIDs) {
                await center.cancel([request.id])
                held.remove(request.id)
                let before = failed.count
                failed.formUnion(request.itemIDs)
                changed = changed || failed.count != before
            }
        }
        return failed
    }
}
