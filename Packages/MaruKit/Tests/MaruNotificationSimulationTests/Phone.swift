// MaruNotificationSimulationTests
//
// A deterministic simulator of iOS local notifications around the REAL Maru code (D086). It exists because the
// notifications of the app were wrong on a real iPhone in spite of unit tests that used a one-line fake center.
//
// What runs for real:
//   ReminderPlan, ReminderEngine, FollowUpPlan, FollowUpEngine, AlarmPlan, AlarmEngine, and a LocalStore on a
//   real SQLite file in a temporary directory. The run order is the one of `AppStore.reconcileReminders`.
//   The action buttons of a notification run the real use cases (`LocalStore.recordOpenDoses`, `LocalStore.snoozeEntry`,
//   and the snooze store of the follow-up engine) through `Phone.perform` (D090).
//
// What is simulated (`FakeNotificationCenter`, `FakeAlarmCenter`, `SimDevice`):
//   the pending and the delivered sets, calendar triggers that repeat, dated triggers, one-time triggers, delivery
//   when the virtual clock passes a fire time, replace by identifier, removal that completes later, the 64 pending
//   limit, permission states, a time zone change, a process that stops in the middle of a run, and an app that does
//   not open for days.
//
// How a scenario reads: the test drives a `Phone` with user actions (`addItem`, `archive`, `record`, ...) and clock
// moves (`advance`). `Phone` keeps its own `Truth` of what the user did. `Oracle` compares every pending request,
// every delivered notification, and every alarm with that truth. The oracle never reads the engines or the database.
//
// The invariant (D084, D086): every pending request and every delivered Maru notification names exactly the open
// doses that Today shows for its occurrence, and every open dose with a time has a reminder before its time.
// Since D090 the oracle also checks the category and the level of every pending request, and that a snooze of the user
// has one request while its group has an open dose, and that the follow-ups of its group wait.
//
// The maintainer asked for this harness explicitly, so it goes beyond the usual test limit of D016.
// The gaps between the fake and real iOS are in `docs/research/2026-10-15-notification-correctness.md`.

import Foundation
import GRDB
@testable import MaruDatabase
import Testing
@testable import MaruCore
@testable import MaruNotifications

/// A temporary directory that goes away with the value.
final class SimDirectory: Sendable {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("MaruSim-\(UUID().uuidString)", isDirectory: true)
    init() { try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    deinit { try? FileManager.default.removeItem(at: url) }
}

/// The durable counter in the defaults of the simulated device. It keeps its value when the process stops.
final class SimCounter: GenerationCounter, @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int { lock.withLock { value += 1; return value } }
    var current: Int { lock.withLock { value } }
}

/// The flag of the move from build 6, in the defaults of the simulated device.
final class SimMigration: LegacyMigration, @unchecked Sendable {
    private let lock = NSLock()
    private var done: Bool
    init(done: Bool = false) { self.done = done }
    var isDone: Bool { lock.withLock { done } }
    func markDone() { lock.withLock { done = true } }
    func reset() { lock.withLock { done = false } }
}

final class SimPrivacy: ReminderPrivacyStore, @unchecked Sendable {
    private let lock = NSLock()
    private var privacy = ReminderPrivacy.showNames
    func load() -> ReminderPrivacy { lock.withLock { privacy } }
    func save(_ privacy: ReminderPrivacy) { lock.withLock { self.privacy = privacy } }
}

/// The life of one app process. A kill makes every later call of the process a no-op, as if the system stopped it.
final class Life: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private var killed = false
    private let killAtCall: Int?
    private let interleave: [Int: @Sendable () async -> Void]

    /// - Parameters:
    ///   - killAtCall: The number of the call of the system that never runs, because the process stops before it.
    ///   - interleave: An action of the user or of the world that runs just before the call with this number.
    init(killAtCall: Int? = nil, interleave: [Int: @Sendable () async -> Void] = [:]) {
        self.killAtCall = killAtCall
        self.interleave = interleave
    }

    var alive: Bool { lock.withLock { !killed } }
    var callCount: Int { lock.withLock { calls } }

    /// Counts one call of the system. `false` when the process is dead, also for the call that kills it.
    func gate() async -> Bool {
        let number = lock.withLock { () -> Int in
            calls += 1
            if calls == killAtCall { killed = true }
            return calls
        }
        if let action = interleave[number] { await action() }
        return alive
    }
}

/// The notification system as one process sees it. After the process stops, calls change nothing.
struct ProcessCenter: FollowUpCenter {
    let base: FakeNotificationCenter
    let life: Life

    func authorization() async -> ReminderAuthorization {
        _ = await life.gate()
        return await base.authorization()
    }

    func requestAuthorization() async -> ReminderAuthorization {
        guard await life.gate() else { return await base.authorization() }
        return await base.requestAuthorization()
    }

    func pendingRequests() async -> [PendingReminder] {
        guard await life.gate() else { return await base.pendingRequestsAfterQueuedRemovals() }
        return await base.pendingRequests()
    }

    func add(_ request: ReminderRequest) async throws {
        guard await life.gate() else { return }
        try await base.add(request)
    }

    func add(_ request: FollowUpRequest) async throws {
        guard await life.gate() else { return }
        try await base.add(request)
    }

    func remove(identifiers: [String]) async {
        guard await life.gate() else { return }
        await base.remove(identifiers: identifiers)
    }

    func delivered() async -> [PendingReminder] {
        _ = await life.gate()
        return await base.delivered()
    }

    func removeDelivered(identifiers: [String]) async {
        guard await life.gate() else { return }
        await base.removeDelivered(identifiers: identifiers)
    }

    func text(for content: ReminderContent) -> ReminderText { base.text(for: content) }
}

/// The database as one process sees it. A write after the process stopped does not happen.
struct ProcessSource: ReminderPlanSource, FollowUpSource, AlarmSource {
    let store: LocalStore
    let life: Life

    func reminderPlan(at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover) async throws -> ReminderPlan {
        try await store.reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: privacy, alarms: alarms)
    }

    func followUpPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover, snoozes: [SnoozeEntry]
    ) async throws -> FollowUpPlan {
        try await store.followUpPlan(privacy: privacy, at: now, deviceTimeZone: deviceTimeZone, alarms: alarms, snoozes: snoozes)
    }

    func confirmFollowUpChanges(at time: Date) async throws {
        guard life.alive else { return }
        try await store.confirmFollowUpChanges(at: time)
    }

    func alarmPlan(privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover) async throws -> AlarmPlan {
        try await store.alarmPlan(privacy: privacy, at: now, deviceTimeZone: deviceTimeZone, alarms: alarms)
    }
}

/// The alarm system as one process sees it.
struct ProcessAlarmCenter: AlarmCenter {
    let base: FakeAlarmCenter
    let life: Life
    func waiting() async throws -> Set<UUID> {
        _ = await life.gate()
        return await base.waiting()
    }

    func active() async throws -> Set<UUID> {
        _ = await life.gate()
        return await base.active()
    }

    func snapshot() async throws -> AlarmSnapshot {
        _ = await life.gate()
        return await base.snapshot()
    }

    func schedule(_ request: AlarmRequest) async throws {
        guard await life.gate() else { return }
        try await base.schedule(request)
    }

    func cancel(_ ids: [UUID]) async throws {
        guard await life.gate() else { return }
        try await base.cancel(ids)
    }
}

/// A box for a value that a `@Sendable` closure reads.
final class Locked<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func get() -> Value { lock.withLock { value } }
    func set(_ value: Value) { lock.withLock { self.value = value } }
}

/// The app process uses the three engines and the `AppStore` queue with persistent request generations.
final class SimProcess: @unchecked Sendable {
    let life: Life
    let reminders: ReminderEngine
    let followUps: FollowUpEngine
    let alarms: AlarmEngine
    private let cover = Locked(AlarmCover.none)
    private let alarmsAllowed: @Sendable () -> Bool
    private var updates: Task<Void, Never>?

    init(phone: Phone, life: Life) {
        self.life = life
        let source = ProcessSource(store: phone.store, life: life)
        let center = ProcessCenter(base: phone.center, life: life)
        let cover = cover
        let coverNow: @Sendable () -> AlarmCover = { cover.get() }
        let device = phone.device
        alarmsAllowed = { device.alarmsAllowed }
        let wanted = WantedAlarms()
        reminders = ReminderEngine(
            source: source, center: center, privacy: phone.privacy,
            alarms: coverNow, clock: { device.now }, generations: phone.counter, migration: phone.seriesMigration
        )
        followUps = FollowUpEngine(
            source: source, center: center, privacy: phone.privacy, snoozes: phone.snoozes,
            alarms: coverNow, clock: { device.now }, generations: phone.counter, migration: phone.followUpMigration
        )
        alarms = AlarmEngine(
            source: source,
            center: TimedAlarmCenter(base: ProcessAlarmCenter(base: phone.alarmCenter, life: life), wanted: wanted, limit: .milliseconds(200)), privacy: phone.privacy,
            alarmsRing: { device.alarmsAllowed },
            wanted: wanted,
            generations: phone.counter,
            index: phone.alarmIndex
        )
    }

    /// The same steps as `AppStore.reconcileReminders`: the alarms, then the series reminders, then the follow-ups.
    /// Each run waits for the run before it.
    @discardableResult
    func reconcile(
        at now: Date, zone: NamedTimeZone, mayAskForPermission: Bool = false
    ) async throws -> (reminders: ReminderOutcome, followUps: FollowUpOutcome?) {
        let previous = updates
        let run = Task { () throws -> (reminders: ReminderOutcome, followUps: FollowUpOutcome?) in
            await previous?.value
            self.cover.set(.none)
            if let failed = try? await self.alarms.refresh(at: now, deviceTimeZone: zone) {
                self.cover.set(AlarmCover(rings: self.alarmsAllowed(), failed: failed))
            }
            let outcome = try await self.reminders.reconcile(at: now, deviceTimeZone: zone, mayAskForPermission: mayAskForPermission)
            let followUps = try? await self.followUps.refresh(at: now, deviceTimeZone: zone)
            return (outcome, followUps)
        }
        updates = Task { _ = try? await run.value }
        return try await run.value
    }
}

/// The whole simulated phone: the device, the notification system, the database, the user's truth, and the app.
final class Phone: @unchecked Sendable {
    let device: SimDevice
    let center: FakeNotificationCenter
    let alarmCenter = FakeAlarmCenter()
    /// The durable index of the alarms. It survives the stop of the app process.
    let alarmIndex = MemoryAlarmIndex()
    let store: LocalStore
    let privacy = SimPrivacy()
    /// The snoozes of the user. They live in the defaults of the device, so a stop of the app keeps them (D090).
    let snoozes = MemorySnoozeStore()
    let counter = SimCounter()
    let seriesMigration = SimMigration()
    let followUpMigration = SimMigration()
    private let directory = SimDirectory()
    var truth = Truth()
    /// The records that the app keeps of each item, so an edit can save the whole value again.
    private var models: [String: (item: Item, schedule: Schedule)] = [:]
    private(set) var process: SimProcess?
    /// `true` after a clock move with no run: the app is in the background or stopped.
    private var needsOpen = true
    /// The next run stops after this call of the system, or runs an action before one of its calls.
    var nextRunKillsAtCall: Int?
    var nextRunInterleave: [Int: @Sendable () async -> Void] = [:]
    /// The number of calls of the system in the last run.
    private(set) var callsInLastRun = 0
    /// Violations that the oracle found at a delivery.
    private(set) var deliveryViolations: [String] = []
    /// A scenario can turn the check of the oracle off for a case that the design accepts.
    var checks = Oracle.Checks()
    /// Check the invariant after every run. A scenario of a known gap can turn it off.
    var autoCheck = true
    /// The next run may show the permission prompt, as the run after a confirmed save does (spec 2.2). `addItem` sets it.
    var asksForPermissionInNextRun = false
    /// The random edit tests check the run (no error, no "not set"). They leave the content checks to the scenarios.
    var checkOracle = true

    /// - Parameter fixture: A database file that an earlier version of the app left. The phone opens a copy of it, so the
    ///   store migrates it as an update does. The oracle knows nothing of its items, so a scenario turns it off.
    static func make(
        zone: String = "Australia/Sydney", start: String = "2026-10-14 12:00", fixture: URL? = nil
    ) async throws -> Phone {
        let zone = try NamedTimeZone(identifier: zone)
        let device = SimDevice(now: Date(), zone: zone)
        let phone = try Phone(device: device, fixture: fixture)
        device.now = phone.instant(start)
        return phone
    }

    private init(device: SimDevice, fixture: URL?) throws {
        self.device = device
        center = FakeNotificationCenter(device: device)
        let directory = directory
        if let fixture {
            try FileManager.default.copyItem(at: fixture, to: directory.url.appendingPathComponent("maru.sqlite"))
        }
        store = try LocalStore(directory: directory.url)
    }

    // MARK: Time

    /// An instant from `yyyy-MM-dd HH:mm` in the time zone of the device now.
    func instant(_ text: String, in zone: NamedTimeZone? = nil) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = (zone ?? device.zone).systemZone
        return formatter.date(from: text)!
    }

    var now: Date { device.now }

    func today(in zone: NamedTimeZone? = nil) -> LocalDate { LocalDate(device.now, in: zone ?? device.zone) }

    func date(_ text: String) -> LocalDate {
        let parts = text.split(separator: "-").map { Int($0)! }
        return try! LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Moves the clock. The app does not run. The system delivers what fires, and the oracle checks each delivery.
    func advance(to text: String) async {
        await advance(to: instant(text))
    }

    func advance(to time: Date) async {
        let before = await center.deliveries.count
        let from = device.now
        await center.advance(to: time)
        await alarmCenter.advance(from: from, to: time, zone: device.zone)
        let delivered = await center.deliveries.dropFirst(before)
        for delivery in delivered {
            deliveryViolations += Oracle(phone: self).violations(of: delivery)
        }
        needsOpen = true
    }

    // MARK: The process

    /// A new process uses persistent request generations and runs the launch queue.
    func launch() async {
        let life = Life(killAtCall: nextRunKillsAtCall, interleave: nextRunInterleave)
        nextRunKillsAtCall = nil
        nextRunInterleave = [:]
        let process = SimProcess(phone: self, life: life)
        self.process = process
        needsOpen = false
        await run(process)
    }

    /// The app comes to the front. A stopped app starts again.
    func foreground() async {
        guard let process, process.life.alive else { return await launch() }
        needsOpen = false
        await run(process)
    }

    /// The system stops the app, or the user swipes it away, or the iPhone restarts.
    func terminate() {
        process = nil
        needsOpen = true
    }

    /// A restart of the iPhone. Pending requests stay in the system. The app does not run until the user opens it.
    func restart() {
        terminate()
    }

    /// The outcome of the last run, and the error if it threw. A run that throws is a failure of the app (D086).
    private(set) var lastOutcome: (reminders: ReminderOutcome, followUps: FollowUpOutcome?)?
    private(set) var lastError: (any Error)?
    /// The device zone that a completed run saw, and since when: the value of `DefaultsTimeZoneRecord`. A reminder action reads it (spec 8.3).
    private(set) var observedZone: ObservedTimeZone?

    private func run(_ process: SimProcess, check: Bool = true) async {
        lastError = nil
        let mayAsk = asksForPermissionInNextRun
        asksForPermissionInNextRun = false
        do {
            lastOutcome = try await process.reconcile(at: device.now, zone: device.zone, mayAskForPermission: mayAsk)
            if observedZone?.timeZone != device.zone { observedZone = ObservedTimeZone(timeZone: device.zone, since: device.now) }
        } catch {
            lastOutcome = nil
            lastError = error
        }
        callsInLastRun = process.life.callCount
        // The invariant runs after every completed run, in every scenario. A run that the process did not survive,
        // or that raced with a user action, is checked by the run after it.
        guard autoCheck, check, process.life.alive else { return }
        let label = "after the run at \(Oracle.format(device.now, device.zone))"
        if let lastError { Issue.record("\(label): the run threw \(lastError)") }
        if checkOracle { await expectCorrect(label) }
        if let outcome = lastOutcome { expectOutcomeIsClean(outcome, label) }
    }

    /// What the app tells the user after a save: no schedule is "not set", and no removal is open.
    private func expectOutcomeIsClean(_ outcome: (reminders: ReminderOutcome, followUps: FollowUpOutcome?), _ label: String) {
        guard device.authorization == .authorized else { return }
        for (_, state) in outcome.reminders.schedules {
            switch state {
            case .scheduled, .off: break
            case .notSet(.overLimit) where checks.allowsOverLimit: break
            default: Issue.record("\(label): the app would show \"Reminder Not Set\" or \"Not Confirmed\": \(state)")
            }
        }
        if outcome.reminders.removalPending { Issue.record("\(label): a series removal is still open") }
        if outcome.followUps == nil { Issue.record("\(label): the follow-up refresh failed") }
        if outcome.followUps?.removalPending == true { Issue.record("\(label): a follow-up removal is still open") }
    }

    /// The user is in the app. An app that was in the background or stopped runs first, as it does at return or launch.
    private func open() async {
        if process == nil || process?.life.alive == false {
            await launch()
        } else if needsOpen {
            await foreground()
        }
    }

    /// The run after a save, a record, a skip, or an undo. It uses the kill or the interleaved action of the scenario.
    private func runAfterChange() async {
        truth.pruneSnoozes(at: device.now, deviceZone: device.zone)
        guard let process, process.life.alive else { return await launch() }
        guard nextRunKillsAtCall != nil || !nextRunInterleave.isEmpty else { return await run(process) }
        let racing = !nextRunInterleave.isEmpty
        // A fresh life for this run: the kill and the interleave count its calls from 1.
        let life = Life(killAtCall: nextRunKillsAtCall, interleave: nextRunInterleave)
        nextRunKillsAtCall = nil
        nextRunInterleave = [:]
        let next = SimProcess(phone: self, life: life)
        self.process = next
        await run(next, check: !racing)
    }

    // MARK: Permissions and the world

    func setNotifications(_ authorization: ReminderAuthorization) async {
        device.authorization = authorization
    }

    func setAlarmsAllowed(_ allowed: Bool) {
        device.alarmsAllowed = allowed
    }

    func changeZone(to identifier: String) throws {
        device.zone = try NamedTimeZone(identifier: identifier)
        needsOpen = true
    }

    func setPrivacy(_ value: ReminderPrivacy) async {
        await open()
        privacy.save(value)
        await runAfterChange()
    }

    // MARK: User actions (each one: open the app, change the data, run the queue)

    @discardableResult
    func addItem(
        _ name: String, at times: [String], days: SimDays = .everyDay, zone: SimZone = .device,
        followUp: FollowUpSetting? = nil, alarm: Bool = false, paused: Bool = false, dose: String? = nil,
        startsToday: Bool = false
    ) async throws -> ItemID {
        await open()
        let item = try Item(personID: store.meID, category: .supplement, name: name, form: .capsule, color: .pink, followUp: followUp, alarm: alarm)
        var schedule = Schedule(itemID: item.id, isEnabled: !paused)
        var slots: [SimSlot] = []
        var slotTimes: [SlotTime] = []
        // The edit screen starts a new schedule on the day of the save, in the zone of the schedule (spec 7.1).
        let start: LocalDate
        if startsToday {
            start = if case let .fixed(zone) = zone { today(in: zone) } else { today() }
        } else {
            start = try LocalDate(year: 2026, month: 1, day: 1)
        }
        for text in times {
            let slot = try schedule.addSlot()
            let time = Self.wallClock(text)
            slotTimes.append(SlotTime(slotID: slot.id, time: time))
            slots.append(SimSlot(id: slot.id, times: [(start, time)]))
        }
        let policy: TimeZonePolicy = switch zone {
        case .device: .followsDevice
        case let .fixed(zone): .fixed(zone)
        }
        let rule: WeeklyRule
        var cycle: DayCycle?
        switch days {
        case .everyDay: rule = .everyDay
        case let .weekdays(weekdays): rule = try WeeklyRule(weekdays: weekdays)
        case let .cycle(on, off, from):
            rule = .everyDay
            cycle = try DayCycle(start: from, daysOn: on, daysOff: off)
        }
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id, effectiveFrom: start, weeklyRule: rule, dayCycle: cycle, slotTimes: slotTimes,
                dose: dose.flatMap(Dose.init), timeZonePolicy: policy
            )
        )
        try await store.save(item, schedule: schedule)
        asksForPermissionInNextRun = true
        models[name] = (item, schedule)
        truth.items.append(
            SimItem(
                id: item.id, scheduleID: schedule.id, name: name, isPaused: paused, followUp: followUp, alarm: alarm,
                slots: slots, days: days, zone: zone
            )
        )
        await runAfterChange()
        return item.id
    }

    func changeTime(_ name: String, slot: Int = 0, to text: String) async throws {
        await open()
        var model = models[name]!
        let slotID = model.schedule.slots[slot].id
        let time = Self.wallClock(text)
        let from = zoneToday(of: name)
        try model.schedule.changeTime(of: slotID, to: time, effectiveFrom: from)
        try await store.save(model.item, schedule: model.schedule)
        models[name] = model
        let index = truth.index(of: name)
        truth.items[index].slots[slot].times.append((from, time))
        await runAfterChange()
    }

    /// Adds one more time of day to the item, from today.
    func addTime(_ name: String, _ text: String) async throws {
        await open()
        var model = models[name]!
        let latest = model.schedule.versions.last!
        let from = zoneToday(of: name)
        let slot = try model.schedule.addSlot()
        let time = Self.wallClock(text)
        try model.schedule.appendVersion(
            ScheduleVersion(
                scheduleID: model.schedule.id, effectiveFrom: from, weeklyRule: latest.weeklyRule, dayCycle: latest.dayCycle,
                slotTimes: latest.slotTimes + [SlotTime(slotID: slot.id, time: time)], dose: latest.dose,
                timeZonePolicy: latest.timeZonePolicy
            )
        )
        try await store.save(model.item, schedule: model.schedule)
        models[name] = model
        let index = truth.index(of: name)
        truth.items[index].slots.append(SimSlot(id: slot.id, times: [(from, time)]))
        await runAfterChange()
    }

    /// A new schedule version with another dose text, from today. The times and the names stay, so a delivered notification stays true,
    /// and the version of its doses is not the version of the plan any more (D089).
    func changeDose(_ name: String, to text: String) async throws {
        await open()
        var model = models[name]!
        let latest = model.schedule.versions.last!
        try model.schedule.appendVersion(
            ScheduleVersion(
                scheduleID: model.schedule.id, effectiveFrom: zoneToday(of: name), weeklyRule: latest.weeklyRule,
                dayCycle: latest.dayCycle, slotTimes: latest.slotTimes, dose: Dose(text), timeZonePolicy: latest.timeZonePolicy
            )
        )
        try await store.save(model.item, schedule: model.schedule)
        models[name] = model
        await runAfterChange()
    }

    /// The date from which an edit applies: today in the zone of the schedule, as the edit screen computes it.
    private func zoneToday(of name: String) -> LocalDate {
        if case let .fixed(zone) = truth.items[truth.index(of: name)].zone { today(in: zone) } else { today() }
    }

    /// An item with no schedule. The user can record it at any time (D021).
    func addAsNeededItem(_ name: String) async throws -> Item {
        await open()
        let item = try Item(personID: store.meID, category: .medication, name: name, form: .tablet, color: .orange)
        try await store.save(item)
        await runAfterChange()
        return item
    }

    /// "Take Now" on an as-needed item. The app runs the notification queue after each record.
    func takeAsNeeded(_ item: Item) async throws {
        await open()
        let dose = AsNeededOccurrence(itemID: item.id, at: device.now, in: device.zone)
        let event = IntakeEvent(
            occurrenceID: dose.id, action: .taken, occurredAt: device.now, recordedAt: device.now, source: .app
        )
        try await store.recordAsNeeded(event, occurrence: dose)
        await runAfterChange()
    }

    /// Adds a version that starts before the version before it. The schedule of the item does not load any more, as stored
    /// data from a bug of an older build would not (D088).
    func corruptSchedule(_ name: String) async throws {
        let item = truth.items[truth.index(of: name)]
        let version = UUID().uuidString
        let scheduleID = item.scheduleID.rawValue.uuidString
        let slotID = item.slots[0].id.rawValue.uuidString
        try await store.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO scheduleVersion (id, scheduleID, position, effectiveFrom, weekdays, dose, timeZonePolicy, timeZone)
                    VALUES (?, ?, 99, '2000-01-01', '1234567', NULL, 'followsDevice', NULL)
                    """,
                arguments: [version, scheduleID]
            )
            try db.execute(
                sql: "INSERT INTO scheduleVersionSlot (scheduleVersionID, slotID, position, time) VALUES (?, ?, 0, '09:00')",
                arguments: [version, slotID]
            )
        }
    }

    /// The current times of the item as `HH:MM`, in the order of its slots.
    func times(of name: String) async -> [String] {
        truth.items[truth.index(of: name)].slots.compactMap { $0.times.last?.time }
            .map { String(format: "%02d:%02d", $0.hour, $0.minute) }
    }

    func rename(_ name: String, to newName: String) async throws {
        try await edit(name) { item, _ in try item.rename(newName) } truth: { $0.name = newName }
        models[newName] = models.removeValue(forKey: name)
    }

    func archive(_ name: String) async throws {
        try await edit(name) { item, _ in item.isArchived = true } truth: { $0.isArchived = true }
    }

    func restore(_ name: String) async throws {
        try await edit(name) { item, _ in item.isArchived = false } truth: { $0.isArchived = false }
    }

    func pause(_ name: String) async throws {
        try await edit(name) { _, schedule in schedule.isEnabled = false } truth: { $0.isPaused = true }
    }

    func resume(_ name: String) async throws {
        try await edit(name) { _, schedule in schedule.isEnabled = true } truth: { $0.isPaused = false }
    }

    func setFollowUp(_ name: String, _ setting: FollowUpSetting?) async throws {
        let now = device.now
        try await edit(name) { item, _ in
            item.followUp = setting
            item.followUpChanged = now
        } truth: { $0.followUp = setting }
    }

    func setAlarm(_ name: String, _ isOn: Bool) async throws {
        try await edit(name) { item, _ in item.alarm = isOn } truth: { $0.alarm = isOn }
    }

    /// "For All Items" in Settings (D085): one transaction for every active item with a time, then one run.
    func setAllFollowUp(_ setting: FollowUpSetting?) async throws {
        await open()
        try await store.apply(.followUp(setting), toTimedItemsAt: device.now)
        for index in truth.items.indices where !truth.items[index].isArchived {
            truth.items[index].followUp = setting
            models[truth.items[index].name]!.item.followUp = setting
        }
        await runAfterChange()
    }

    func setAllAlarm(_ isOn: Bool) async throws {
        await open()
        try await store.apply(.alarm(isOn), toTimedItemsAt: device.now)
        for index in truth.items.indices where !truth.items[index].isArchived {
            truth.items[index].alarm = isOn
            models[truth.items[index].name]!.item.alarm = isOn
        }
        await runAfterChange()
    }

    func delete(_ name: String) async throws {
        await open()
        let model = models.removeValue(forKey: name)!
        try await store.deleteItem(model.item.id)
        let removed = truth.items.remove(at: truth.index(of: name))
        for slot in removed.slots { truth.closed = truth.closed.filter { $0.slot != slot.id } }
        await runAfterChange()
    }

    private func edit(
        _ name: String, _ change: (inout Item, inout Schedule) throws -> Void, truth update: (inout SimItem) -> Void
    ) async throws {
        await open()
        var model = models[name]!
        try change(&model.item, &model.schedule)
        try await store.save(model.item, schedule: model.schedule)
        models[name] = model
        update(&truth.items[truth.index(of: name)])
        await runAfterChange()
    }

    /// "Taken", "Skip" on Today, or the same on a past dose. `date` is the plan date. With `nil`, it is today in the zone of the item.
    func record(_ name: String, slot: Int = 0, _ action: IntakeAction = .taken, date: LocalDate? = nil) async throws {
        await open()
        try await write(name, slot: slot, action, date: date)
        await runAfterChange()
    }

    /// A record from the widget: the app starts in the background if it is not running, records, and runs the queue (D048).
    func recordFromWidget(_ name: String, slot: Int = 0) async throws {
        if process == nil || process?.life.alive == false { await launch() }
        try await write(name, slot: slot, .taken, date: nil)
        await runAfterChange()
    }

    /// The state of an iPhone with build 6: no request has a generation, the move to generations is not done, and the system
    /// still holds two removals that build 6 sent.
    func downgradeToBuild6(pendingRemovals: [String] = []) async {
        let strip: (String) -> String = { id in
            guard let range = id.range(of: #"\|g\d{12}r[0-9a-f]{4}$"#, options: .regularExpression) else { return id }
            return String(id[..<range.lowerBound])
        }
        await center.rewriteIdentifiers(strip)
        seriesMigration.reset()
        followUpMigration.reset()
        for (id, latency) in zip(pendingRemovals, 3...) { await center.queueRemoval([id], afterReads: latency) }
        terminate()
    }

    /// A record that commits while a run is in progress. It starts no run of its own.
    /// The app is not running its reminders yet, so a delivered notification can still name a dose that has a record.
    func recordWithoutRun(_ name: String, _ action: IntakeAction = .taken) async throws {
        try await write(name, slot: 0, action, date: nil)
    }

    /// The state of one dose in the database. With `nil`, the date is today in the zone of the item.
    func status(of name: String, slot: Int = 0, date: LocalDate? = nil) async throws -> OccurrenceStatus {
        let item = truth.items[truth.index(of: name)]
        let zone: NamedTimeZone = if case let .fixed(zone) = item.zone { zone } else { device.zone }
        let occurrence = try #require(try await store.occurrence(slotID: item.slots[slot].id, on: date ?? today(in: zone)))
        return try await store.status(of: occurrence.id)
    }

    func undo(_ name: String, slot: Int = 0, date: LocalDate? = nil) async throws {
        try await record(name, slot: slot, .undo, date: date)
    }

    /// What the user chooses on a delivered notification (spec 8.3, D034, D090).
    enum Action {
        case taken
        case skip
        case snooze
    }

    /// An action button of a delivered notification. The system removes the notification, the app starts in the background if it is
    /// not running, the real use case of the app runs on the real database, and the app runs the reminders and waits for them (D083).
    ///
    /// `Truth` changes by what the action is meant to do, and the stored state is then checked against it. The result is what the
    /// use case reports, so a scenario can check the count of recorded doses. A snooze returns `nil`, and a record that found no dose
    /// returns a result with no dose.
    @discardableResult
    func perform(_ action: Action, on identifier: String) async throws -> ReminderActionResult? {
        let delivered = try #require(await center.shown[identifier], "no delivered notification \(identifier)")
        let weekday: Weekday?
        if case let .calendar(components, _) = delivered.notification.trigger {
            weekday = components.weekday.flatMap(Weekday.init(calendarWeekday:))
        } else {
            weekday = nil
        }
        let reminder = DeliveredReminder(deliveredAt: delivered.date, userInfo: delivered.notification.userInfo, triggerWeekday: weekday)
        await center.dismiss(identifier)
        await open()
        let now = device.now
        switch action {
        case .taken, .skip:
            let result = try await store.recordOpenDoses(
                for: reminder, action: action == .taken ? .taken : .skipped, at: now, deviceTimeZone: device.zone,
                observedTimeZone: observedZone
            )
            for dose in result.doses {
                if case .recorded = dose.outcome { truth.closed.insert(ClosedKey(slot: dose.key.slotID, date: dose.key.plannedDate)) }
            }
            await expectStoredMatchesTruth("after the action on \(identifier)")
            // The call waits for the reminder run only after a record, as the app does.
            if !result.recorded.isEmpty { await runAfterChange() }
            return result
        case .snooze:
            guard let entry = try await store.snoozeEntry(
                for: reminder, at: now, deviceTimeZone: device.zone, observedTimeZone: observedZone
            ) else { return nil }
            snoozes.add(entry)
            // The group of the notification, read from the notification and not from the entry.
            let parts = Oracle.parts(of: identifier)
            let date = Self.parseDate(delivered.notification.userInfo["plannedDate"]) ?? parts.date
                ?? LocalDate(delivered.date, in: device.zone)
            truth.snoozes.append(SimSnooze(date: date, time: parts.time, fireAt: entry.fireAt))
            await runAfterChange()
            return nil
        }
    }

    static func parseDate(_ text: String?) -> LocalDate? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return try? LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }

    /// Every stored occurrence of the items around today has the state that `Truth` says: closed if and only if the user closed it.
    func expectStoredMatchesTruth(_ label: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        for item in truth.items {
            for slot in item.slots {
                for offset in -1...1 {
                    let zone: NamedTimeZone = if case let .fixed(zone) = item.zone { zone } else { device.zone }
                    let date = today(in: zone).adding(days: offset)
                    guard let occurrence = try? await store.occurrence(slotID: slot.id, on: date),
                          let status = try? await store.status(of: occurrence.id)
                    else { continue }
                    let closed = truth.closed.contains(ClosedKey(slot: slot.id, date: date))
                    #expect(
                        (status != .unrecorded) == closed,
                        "\(label): \(item.name) on \(date) is \(status) in the database, and the user closed it: \(closed)",
                        sourceLocation: sourceLocation
                    )
                }
            }
        }
    }

    private func write(_ name: String, slot: Int, _ action: IntakeAction, date: LocalDate?) async throws {
        let index = truth.index(of: name)
        let item = truth.items[index]
        let zone: NamedTimeZone = switch item.zone {
        case .device: device.zone
        case let .fixed(zone): zone
        }
        let date = date ?? today(in: zone)
        // Today generates the occurrences of the window before it shows a row (spec 7.3).
        try await store.generateOccurrences(at: device.now, deviceTimeZone: device.zone)
        let slotID = item.slots[slot].id
        guard let occurrence = try await store.occurrence(slotID: slotID, on: date) else {
            Issue.record("No stored occurrence for \(name) on \(date)")
            return
        }
        let history = try await store.history(of: occurrence.id)
        let event = IntakeEvent(
            occurrenceID: occurrence.id, action: action, occurredAt: device.now, recordedAt: device.now, source: .app,
            supersedes: history.events.last?.id
        )
        try await store.record([(event, occurrence.scheduleVersionID)])
        let key = ClosedKey(slot: slotID, date: date)
        if action == .undo { truth.closed.remove(key) } else { truth.closed.insert(key) }
    }

    // MARK: Checks

    /// The violations of the invariant now, from the oracle. Call it after a run.
    func violations() async -> [String] {
        await Oracle(phone: self).violations()
    }

    /// Fails the test with every violation, and with the pending and delivered requests as the oracle saw them.
    func expectCorrect(_ label: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        let found = await violations()
        let dump = await Oracle(phone: self).dump()
        #expect(found.isEmpty, "\(label)\n\(found.joined(separator: "\n"))\n\(dump)", sourceLocation: sourceLocation)
    }

    /// Fails the test with every notification that the system delivered with wrong content.
    func expectCorrectDeliveries(_ label: String = "deliveries", sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(deliveryViolations.isEmpty, "\(label)\n\(deliveryViolations.joined(separator: "\n"))", sourceLocation: sourceLocation)
    }

    static func wallClock(_ text: String) -> WallClockTime {
        let parts = text.split(separator: ":").map { Int($0)! }
        return try! WallClockTime(hour: parts[0], minute: parts[1])
    }
}

extension LocalStore {
    /// The member "Me" that the migration of every database made.
    var meID: PersonID {
        try! writer.read { db in try Self.fetchPeople(db).first { $0.kind == .me }!.id }
    }
}
