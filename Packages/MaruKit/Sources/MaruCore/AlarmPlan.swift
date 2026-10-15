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

/// One alarm that rings at the time of a dose (D079). It is one alarm for one slot time on one date, or one alarm that
/// repeats on some weekdays at one time of day (D089). The items with an alarm and an open dose at that time share it.
public struct AlarmRequest: Hashable, Sendable {
    /// A repeating alarm of the system: one time of day on some weekdays, on the clock of the device.
    /// It never runs out, so an app that does not open for a month still has its alarm (D089).
    public struct Repeat: Hashable, Sendable {
        public let time: WallClockTime
        public let weekdays: Set<Weekday>
    }

    /// The identifier of the alarm in the system. It comes from the group, the items, and the names, so a change
    /// of the items or of a name gives another identifier, and the engine replaces the alarm.
    public let id: UUID
    /// The instant of the alarm, or of its first ring when it repeats.
    public let fireDate: Date
    /// The items with an open dose at this time that the alarm stands for.
    public let itemIDs: [ItemID]
    /// The names of the items, in the order of the schedules. `nil` when the user hides the names (D029).
    public let names: [String]?
    /// What the "Taken" button needs, when the alarm stands for exactly one item that is alone at its time.
    /// The keys are the ones of a follow-up (D034), so the same checks run. `nil`: the button opens the app.
    /// A repeating alarm has no plan date and no fire time. The button finds the date when it runs (D089).
    public let taken: [String: String]?
    /// `nil` for an alarm of one date.
    public let repeating: Repeat?

    public init(
        id: UUID, fireDate: Date, itemIDs: [ItemID], names: [String]?, taken: [String: String]?, repeating: Repeat? = nil
    ) {
        self.id = id
        self.fireDate = fireDate
        self.itemIDs = itemIDs
        self.names = names
        self.taken = taken
        self.repeating = repeating
    }
}

extension AlarmRequest {
    /// The plan date that the "Taken" button of a repeating alarm stands for, as `YYYY-MM-DD` (D089).
    /// The alarm repeats, so it holds no date. The button is for today's dose, when the dose time of the series has come.
    /// `nil` for a series of a named zone, a bad series ID, or a time that has not come on today's date. The action then records
    /// nothing, and the notice tells the user to open Maru.
    public static func plannedDate(ofSeries seriesID: String, at now: Date, deviceTimeZone: NamedTimeZone) -> String? {
        let parts = seriesID.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[1] == "device" else { return nil }
        let clock = parts[2].split(separator: ":").compactMap { Int($0) }
        guard clock.count == 2, let time = try? WallClockTime(hour: clock[0], minute: clock[1]) else { return nil }
        let today = LocalDate(now, in: deviceTimeZone)
        guard deviceTimeZone.resolve(time, on: today).earliestInstant <= now else { return nil }
        return today.dayText
    }
}

extension UUID {
    /// The alarm identifier without its generation: the 12 bytes of content (D086).
    var alarmContent: UUID {
        let b = uuid
        return UUID(uuid: (b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7, b.8, b.9, b.10, b.11, 0, 0, 0, 0))
    }

    /// The generation: the last 4 bytes. The plan has 0.
    var alarmGeneration: UInt32 {
        let b = uuid
        return UInt32(b.12) << 24 | UInt32(b.13) << 16 | UInt32(b.14) << 8 | UInt32(b.15)
    }

    /// The same content with a generation. The system never sees an alarm identifier twice, so no cancel of an
    /// earlier alarm, late or repeated, can reach a newer alarm of the same content (D086).
    func withGeneration(_ number: Int) -> UUID {
        let b = uuid
        let generation = UInt32(truncatingIfNeeded: number)
        return UUID(uuid: (
            b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7, b.8, b.9, b.10, b.11,
            UInt8(truncatingIfNeeded: generation >> 24), UInt8(truncatingIfNeeded: generation >> 16),
            UInt8(truncatingIfNeeded: generation >> 8), UInt8(truncatingIfNeeded: generation)
        ))
    }
}

/// The exact identifiers (content and generation) of the alarms that the current plan wants: the alarms that the system
/// holds and the alarms that a call of this run is scheduling. A call that returns late checks it, so a late older
/// generation is cancelled also when its content matches (D086).
public final class WantedAlarms: @unchecked Sendable {
    private let lock = NSLock()
    private var exact: Set<UUID> = []

    public init() {}

    /// The start of a run: the ids of the earlier run that the plan still has, by content.
    func begin(keeping content: Set<UUID>) { lock.withLock { exact = exact.filter { content.contains($0.alarmContent) } } }
    func set(_ ids: Set<UUID>) { lock.withLock { exact = ids } }
    func insert(_ id: UUID) { lock.withLock { _ = exact.insert(id) } }
    func remove(_ id: UUID) { lock.withLock { _ = exact.remove(id) } }

    func isWanted(_ id: UUID) -> Bool { lock.withLock { exact.contains(id) } }
}

/// The alarms that the saved plan, the records, and the items ask for (D079).
///
/// An alarm comes for a slot time with an open dose of an item with `alarm`. A dose that has a record gets none, so a record
/// cancels its alarm at the next run (D047). The app sets the alarms again at each run, as it does for the follow-ups.
///
/// A time of day on a weekday that has the same open items on every date of the next `datedDays` days becomes one repeating
/// alarm of the system, when the item follows the device and has no day cycle (D089). It never runs out. Every other dose,
/// also the dose of a weekday with a record before its time, gets one alarm for its date, for the next `datedDays` days.
/// A dose that is due within `minimumDays` and that the limit cut gives its item the normal reminder back.
///
/// It is a value of its inputs and reads no system state.
public struct AlarmPlan: Hashable, Sendable {
    /// The most alarms that the plan holds, the repeating alarms first, then the nearest date. The system documents no limit,
    /// so this is a safe size and not a measured one.
    public static let limit = 64
    /// The alarms of one date come for this many days.
    public static let datedDays = 28
    /// A dose that is due within this many days has an alarm, or its item has the normal reminder (D089).
    public static let minimumDays = 7

    /// The alarms, nearest first.
    public let requests: [AlarmRequest]
    /// A schedule did not load (D088). The engine cancels no waiting alarm, because the plan does not know its alarms.
    public let hasUnreadable: Bool
    /// The items with a dose within `minimumDays` that has no alarm, because the limit cut it (D089).
    /// The engine reports them as failed, so they get the normal reminder.
    public let cutItems: Set<ItemID>

    /// What the doses of one time must have in common to share one repeating alarm.
    private struct Signature: Hashable {
        let items: [ItemID]
        let names: [String]
        let takenItem: ItemID?
        let takenVersion: ScheduleVersionID?
        let seriesID: String
    }

    /// One dose group with an alarm.
    private struct Candidate {
        let group: FollowUpGroup
        let instant: Date
        let items: [ItemID]
        let names: [String]
        let single: (itemID: ItemID, versionID: ScheduleVersionID)?
        /// The item follows the device, and its plan has no day cycle, so a repeating alarm can stand for it.
        let isRepeatable: Bool

        var signature: Signature {
            Signature(
                items: items, names: names, takenItem: single?.itemID, takenVersion: single?.versionID, seriesID: group.seriesID
            )
        }
    }

    private struct ClassKey: Hashable {
        let time: WallClockTime
        let weekday: Weekday
    }

    private struct SharedKey: Hashable {
        let time: WallClockTime
        let signature: Signature
    }

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
        hasUnreadable = !reminders.unreadable.isEmpty
        let ringing = Set(schedules.filter { reminders.needs[$0.id] == .alarm }.map(\.itemID))
        guard !ringing.isEmpty else {
            requests = []
            cutItems = []
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
            reminding: reminding, items: items, stored: stored, closed: closed, now: now, deviceTimeZone: deviceTimeZone,
            days: Self.datedDays
        )
        let end = now.addingTimeInterval(Double(Self.datedDays) * 86_400)
        let scheduleOfItem = Dictionary(schedules.map { ($0.itemID, $0) }, uniquingKeysWith: { first, _ in first })
        var candidates: [Candidate] = []
        for (group, instant) in groups.slotInstants where instant > now && instant <= end {
            let open = groups.orderedOpenItems(of: group).filter { ringing.contains($0.itemID) }
            guard !open.isEmpty else { continue }
            var single: (itemID: ItemID, versionID: ScheduleVersionID)?
            if open.count == 1, let one = groups.single(of: group), one.itemID == open[0].itemID { single = one }
            let isRepeatable = group.seriesTimeZone == nil && group.timeZone == deviceTimeZone
                && open.allSatisfy { scheduleOfItem[$0.itemID]?.version(on: group.plannedDate)?.dayCycle == nil }
            candidates.append(
                Candidate(
                    group: group, instant: instant, items: open.map(\.itemID),
                    names: privacy == .showNames ? open.compactMap(\.name) : [], single: single, isRepeatable: isRepeatable
                )
            )
        }

        // A time and a weekday that has the same open items on every date of the horizon is one repeating alarm.
        let today = LocalDate(now, in: deviceTimeZone)
        func dateCount(of key: ClassKey) -> Int {
            (-1...(Self.datedDays + 1)).filter { offset in
                let date = today.adding(days: offset)
                guard date.weekday == key.weekday else { return false }
                let instant = deviceTimeZone.resolve(key.time, on: date).earliestInstant
                return instant > now && instant <= end
            }.count
        }
        var classes: [ClassKey: [Candidate]] = [:]
        for candidate in candidates where candidate.isRepeatable {
            classes[ClassKey(time: candidate.group.time, weekday: candidate.group.plannedDate.weekday), default: []].append(candidate)
        }
        let uniform = classes.filter { key, list in
            let count = dateCount(of: key)
            return count >= 2 && list.count == count && Set(list.map(\.signature)).count == 1
        }
        var shared: [SharedKey: (weekdays: Set<Weekday>, first: Date, single: (itemID: ItemID, versionID: ScheduleVersionID)?)] = [:]
        for (key, list) in uniform {
            let sharedKey = SharedKey(time: key.time, signature: list[0].signature)
            let first = list.map(\.instant).min()!
            let old = shared[sharedKey]
            shared[sharedKey] = ((old?.weekdays ?? []).union([key.weekday]), min(first, old?.first ?? first), list[0].single)
        }
        var repeating: [AlarmRequest] = []
        for (key, value) in shared {
            let signature = key.signature
            var taken: [String: String]?
            if let single = value.single {
                taken = [
                    ReminderRequest.seriesIDKey: signature.seriesID,
                    FollowUpRequest.itemIDKey: single.itemID.rawValue.uuidString,
                    FollowUpRequest.scheduleVersionIDKey: single.versionID.rawValue.uuidString,
                ]
            }
            let text = (
                ["repeat", signature.seriesID, value.weekdays.sorted().map { String($0.rawValue) }.joined()]
                    + signature.items.map { $0.rawValue.uuidString } + signature.names + [taken == nil ? "open" : "taken"]
            ).joined(separator: "\n")
            repeating.append(
                AlarmRequest(
                    id: Self.identifier(of: text), fireDate: value.first, itemIDs: signature.items,
                    names: signature.names.isEmpty ? nil : signature.names, taken: taken,
                    repeating: AlarmRequest.Repeat(time: key.time, weekdays: value.weekdays)
                )
            )
        }

        // Every other dose has an alarm for its date. A repeating alarm stands for the doses of its classes.
        var dated: [AlarmRequest] = []
        for candidate in candidates {
            if candidate.isRepeatable,
               uniform[ClassKey(time: candidate.group.time, weekday: candidate.group.plannedDate.weekday)] != nil { continue }
            var taken: [String: String]?
            if let single = candidate.single {
                taken = [
                    ReminderRequest.seriesIDKey: candidate.group.seriesID,
                    FollowUpRequest.plannedDateKey: candidate.group.dateText,
                    FollowUpRequest.fireTimeKey: candidate.instant.formatted(.iso8601),
                    FollowUpRequest.itemIDKey: single.itemID.rawValue.uuidString,
                    FollowUpRequest.scheduleVersionIDKey: single.versionID.rawValue.uuidString,
                ]
            }
            let key = ([candidate.group.identifier] + candidate.items.map { $0.rawValue.uuidString } + candidate.names
                + [taken == nil ? "open" : "taken"]).joined(separator: "\n")
            dated.append(
                AlarmRequest(
                    id: Self.identifier(of: key), fireDate: candidate.instant, itemIDs: candidate.items,
                    names: candidate.names.isEmpty ? nil : candidate.names, taken: taken
                )
            )
        }
        let order = { (first: AlarmRequest, second: AlarmRequest) in
            (first.fireDate, first.id.uuidString) < (second.fireDate, second.id.uuidString)
        }
        dated.sort(by: order)
        // The repeating alarms come first. Of the others, the nearest dates stay. A dose that the limit cut and that is due
        // soon gives its item the normal reminder back (D089).
        let room = max(0, Self.limit - repeating.count)
        let soon = now.addingTimeInterval(Double(Self.minimumDays) * 86_400)
        cutItems = Set(dated.dropFirst(room).filter { $0.fireDate <= soon }.flatMap(\.itemIDs))
        requests = (repeating + dated.prefix(room)).sorted(by: order)
    }

    /// A stable identifier from a text: two FNV-1a hashes with two starts make 16 bytes. It tells two texts apart
    /// and protects nothing.
    static func identifier(of text: String) -> UUID {
        func hash(_ start: UInt64) -> [UInt8] {
            let value = text.utf8.reduce(start) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
            return (0..<8).map { UInt8(truncatingIfNeeded: value >> UInt64(56 - 8 * $0)) }
        }
        let bytes = hash(0xcbf2_9ce4_8422_2325) + hash(0x8422_2325_cbf2_9ce4)
        // 12 bytes of content. The last 4 bytes are the generation, and the plan has none (D086).
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], 0, 0, 0, 0
        ))
    }
}

/// The alarm system. The rules of the engine use only this protocol, so they run without AlarmKit (D079).
public protocol AlarmCenter: Sendable {
    /// The identifiers of the alarms that wait for their time. An alarm that rings now is not in the set,
    /// so a run never stops a ringing alarm.
    /// Throws when the system cannot list the alarms, also when it does not answer in time (D086).
    func waiting() async throws -> Set<UUID>
    /// Schedules the alarm. The system holds it until its time.
    func schedule(_ request: AlarmRequest) async throws
    /// Cancels the alarms with these identifiers.
    /// Throws when the system could not cancel an alarm. It still tries each one.
    func cancel(_ ids: [UUID]) async throws
}

/// Where the engine reads the alarms that the saved plan and the records ask for.
public protocol AlarmSource: Sendable {
    /// - Parameter alarms: With `rings` false, the plan has no alarm.
    func alarmPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover
    ) async throws -> AlarmPlan
}

/// A cancel of an alarm failed in a run, or the alarm system did not answer in time.
public enum AlarmRunError: Error { case cancelFailed, timedOut }

/// An alarm center that gives each call a time limit (D086). A call of AlarmKit that never returns would block the one
/// queue of the notification runs, and no reminder would change again. A call that passes the limit throws
/// `AlarmRunError.timedOut`. The engine then fails open: the cover is empty for the run, and every item with an alarm
/// gets its notification (D079). The call that did not return stays in the background, and its result is ignored.
public struct TimedAlarmCenter: AlarmCenter {
    private let base: any AlarmCenter
    private let limit: Duration
    private let didTimeOut: @Sendable (String) -> Void
    private let wanted: WantedAlarms

    /// - Parameters:
    ///   - didTimeOut: Called with the name of the call. It is for a log. It must not hold item data.
    ///   - wanted: The same box as the `AlarmEngine` has.
    public init(
        base: any AlarmCenter, wanted: WantedAlarms, limit: Duration = .seconds(3),
        didTimeOut: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.base = base
        self.limit = limit
        self.didTimeOut = didTimeOut
        self.wanted = wanted
    }

    public func waiting() async throws -> Set<UUID> {
        try await timed("waiting") { try await base.waiting() }
    }

    public func schedule(_ request: AlarmRequest) async throws {
        let wanted = wanted
        let base = base
        // A schedule that returns after the limit can register an alarm for a dose that has a record by now. It checks the
        // latest plan, and it cancels an alarm that the plan does not want (D086).
        try await timed("schedule", late: { _ in
            if !wanted.isWanted(request.id) { try? await base.cancel([request.id]) }
        }) { try await base.schedule(request) }
    }

    public func cancel(_ ids: [UUID]) async throws {
        try await timed("cancel") { try await base.cancel(ids) }
    }

    private func timed<T: Sendable>(
        _ name: String, late: (@Sendable (T) async -> Void)? = nil, _ call: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let gate = Gate<T>()
        let limit = limit
        let didTimeOut = didTimeOut
        return try await withCheckedThrowingContinuation { continuation in
            gate.install(continuation)
            Task {
                do {
                    let value = try await call()
                    // The limit came first: the caller has its error, so the late result goes to the check.
                    if !gate.finish(.success(value)) { await late?(value) }
                } catch { gate.finish(.failure(error)) }
            }
            Task {
                try? await Task.sleep(for: limit)
                if gate.finish(.failure(AlarmRunError.timedOut)) { didTimeOut(name) }
            }
        }
    }

    /// Gives the continuation exactly one result: the call or the limit, whichever comes first.
    private final class Gate<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, any Error>?

        func install(_ continuation: CheckedContinuation<T, any Error>) {
            lock.withLock { self.continuation = continuation }
        }

        @discardableResult
        func finish(_ result: Result<T, any Error>) -> Bool {
            let taken = lock.withLock { () -> CheckedContinuation<T, any Error>? in
                defer { continuation = nil }
                return continuation
            }
            guard let taken else { return false }
            taken.resume(with: result)
            return true
        }
    }
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
    private let wanted: WantedAlarms
    private let generations: any GenerationCounter

    /// - Parameter wanted: The box that the engine fills with the exact ids that the current plan wants. A `TimedAlarmCenter`
    ///   reads it, so a schedule that returns after its time out is cancelled when the plan does not want it any more.
    public init(
        source: any AlarmSource,
        center: any AlarmCenter,
        privacy: any ReminderPrivacyStore,
        alarmsRing: @escaping @Sendable () -> Bool,
        wanted: WantedAlarms = WantedAlarms(),
        generations: any GenerationCounter = MemoryGenerationCounter.shared
    ) {
        self.generations = generations
        self.source = source
        self.center = center
        self.privacy = privacy
        self.alarmsRing = alarmsRing
        self.wanted = wanted
    }

    /// An error from the source stops the run before it changes an alarm. A failed schedule leaves
    /// the alarm out until the next run.
    ///
    /// - Throws: An error of the read or of a cancel. The caller then uses an empty cover for this run (D079).
    /// - Returns: The items with an alarm that the system did not schedule. The notification engines give
    ///   them their normal reminder in the same run (D079). The notification of an item is one repeating request,
    ///   so coverage is for the whole item and not for one dose. When one alarm of an item fails, the run cancels
    ///   the other alarms of that item and of every item that shares an alarm with it. So no dose gets an alarm and
    ///   a banner together.
    public func refresh(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> Set<ItemID> {
        let plan = try await source.alarmPlan(
            privacy: privacy.load(), at: now, deviceTimeZone: deviceTimeZone, alarms: AlarmCover(rings: alarmsRing())
        )
        // The latest plan goes in the box first, so a call of the system that returns late checks the newest plan,
        // also when the next call of this run does not answer.
        let wantedContent = Set(plan.requests.map(\.id))
        wanted.begin(keeping: wantedContent)
        let waiting = try await center.waiting()
        /// The alarms of the system by content. An alarm that the plan does not want goes. Of one content only the alarm with
        /// the highest generation stays.
        var actual: [UUID: UUID] = [:]
        var obsolete: [UUID] = []
        for id in waiting.sorted(by: { $0.alarmGeneration > $1.alarmGeneration }) {
            let content = id.alarmContent
            if wantedContent.contains(content), actual[content] == nil { actual[content] = id } else { obsolete.append(id) }
        }
        wanted.set(Set(actual.values))
        /// Any cancel error makes the whole run fail open: the caller then has an empty cover (D079).
        var cancelFailed = false
        func cancel(_ ids: [UUID]) async -> Bool {
            do {
                try await center.cancel(ids)
                return true
            } catch {
                cancelFailed = true
                return false
            }
        }
        if !obsolete.isEmpty, !plan.hasUnreadable { _ = await cancel(obsolete) }
        // A dose that the limit cut and that is due soon has no alarm. Its item gets the normal reminder (D089).
        var failed = plan.cutItems
        /// The alarms that the system holds after this run, by content. A ringing alarm is not in `waiting` and stays.
        var held = Set(actual.keys)
        for request in plan.requests where actual[request.id] == nil {
            // A fresh identifier for each alarm that the app gives the system (D086).
            let registered = AlarmRequest(
                id: request.id.withGeneration(generations.next()), fireDate: request.fireDate, itemIDs: request.itemIDs,
                names: request.names, taken: request.taken, repeating: request.repeating
            )
            // The id is wanted while the call runs. A call that returns after its limit is checked with it.
            wanted.insert(registered.id)
            do {
                try await center.schedule(registered)
                held.insert(request.id)
                actual[request.id] = registered.id
            } catch {
                // The item now gets its banner. An answer that comes late must not ring beside it, so the id is not wanted
                // any more, and the late check of `TimedAlarmCenter` cancels the alarm (D089).
                wanted.remove(registered.id)
                failed.formUnion(request.itemIDs)
            }
        }
        // Cancel each held alarm of a failed item, until no new item fails with it.
        var changed = !failed.isEmpty
        while changed {
            changed = false
            for request in plan.requests where held.contains(request.id) && !failed.isDisjoint(with: request.itemIDs) {
                // A cancel that failed leaves the alarm held. The run throws at the end, so no banner is dropped.
                if let id = actual[request.id], await cancel([id]) { held.remove(request.id) }
                let before = failed.count
                failed.formUnion(request.itemIDs)
                changed = changed || failed.count != before
            }
        }
        if cancelFailed { throw AlarmRunError.cancelFailed }
        return failed
    }
}
