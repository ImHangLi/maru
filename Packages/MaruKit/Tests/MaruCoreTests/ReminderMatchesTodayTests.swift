import Foundation
import Testing
@testable import MaruCore

/// The saved plan and the notification system of a test, for the series engine and the follow-up engine together.
/// A repeating series request stays pending after it is delivered, as in the system.
private actor Phone: ReminderPlanSource, FollowUpSource, FollowUpCenter, ReminderPrivacyStore {
    var items: [Item] = []
    var schedules: [Schedule] = []
    var pending: [String: (userInfo: [String: String], text: ReminderText)] = [:]
    var shown: [String: PendingReminder] = [:]

    var closed: Set<OccurrenceKey> = []
    var status = ReminderAuthorization.authorized
    func deny() { status = .denied }
    /// The system takes this many next adds with no error and does not keep them.
    var dropsNext = 0

    func save(name: String, timeZonePolicy: TimeZonePolicy = .fixed(Fixtures.shanghai), hour: Int = 8) -> Schedule {
        let item = Fixtures.item(name: name, followUp: FollowUpSetting(count: .two, interval: .minutes15))
        items.append(item)
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(hour)], timeZonePolicy: timeZonePolicy)
        schedules.append(schedule)
        return schedule
    }

    func archive(_ name: String) {
        items = items.map { item in
            var item = item
            if item.name == name { item.isArchived = true }
            return item
        }
    }

    /// The system shows the request now. A one-time request is then no longer pending.
    func drop(_ count: Int) { dropsNext = count }
    func record(_ key: OccurrenceKey) { closed.insert(key) }

    func deliver(_ identifier: String, at date: Date) {
        guard let request = pending[identifier] else { return }
        shown[identifier] = PendingReminder(identifier: identifier, userInfo: request.userInfo, text: request.text, deliveredAt: date)
        if identifier.hasPrefix(FollowUpRequest.identifierPrefix) { pending[identifier] = nil }
    }

    func reminderPlan(at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover) -> ReminderPlan {
        ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy, closed: closed)
    }

    func followUpPlan(privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover) -> FollowUpPlan {
        FollowUpPlan(
            reminders: reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: privacy, alarms: alarms),
            items: items, schedules: schedules, stored: [], closed: closed, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy
        )
    }

    func confirmFollowUpChanges(at time: Date) {}
    func authorization() -> ReminderAuthorization { status }
    func requestAuthorization() -> ReminderAuthorization { .authorized }
    func pendingRequests() -> [PendingReminder] {
        pending.map { PendingReminder(identifier: $0.key, userInfo: $0.value.userInfo, text: $0.value.text) }
    }
    func add(_ request: ReminderRequest) {
        guard dropsNext == 0 else { return dropsNext -= 1 }
        pending[RequestGeneration.base(of: request.identifier)] = (request.userInfo, text(for: request.content))
    }
    func add(_ request: FollowUpRequest) {
        guard dropsNext == 0 else { return dropsNext -= 1 }
        pending[RequestGeneration.base(of: request.identifier)] = (request.userInfo, text(for: request.content))
    }
    func remove(identifiers: [String]) { identifiers.forEach { pending[$0] = nil } }
    func delivered() -> [PendingReminder] { Array(shown.values) }
    func removeDelivered(identifiers: [String]) { identifiers.forEach { shown[$0] = nil } }

    nonisolated func load() -> ReminderPrivacy { .showNames }
    nonisolated func save(_ privacy: ReminderPrivacy) {}
    nonisolated func text(for content: ReminderContent) -> ReminderText { Fixtures.text(for: content) }
}

@Suite("Reminders match Today (D084)")
struct ReminderMatchesTodayTests {
    /// One run of the queue, as `AppStore.reconcileReminders` does it.
    private func run(_ phone: Phone, _ series: ReminderEngine, _ followUps: FollowUpEngine, at now: Date) async throws {
        _ = try await series.reconcile(at: now, deviceTimeZone: Fixtures.shanghai)
        _ = try await followUps.refresh(at: now, deviceTimeZone: Fixtures.shanghai)
    }

    @Test func anArchivedItemOfASharedTimeIsNamedByNoPendingOrDeliveredReminder() async throws {
        let phone = Phone()
        let series = ReminderEngine(source: phone, center: phone, privacy: phone)
        let followUps = FollowUpEngine(source: phone, center: phone, privacy: phone)
        _ = await phone.save(name: "Zinc")
        _ = await phone.save(name: "Iron")

        // 08:00 in Shanghai. The first reminder is delivered, and so is the first follow-up at 08:15.
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-01T23:55:00Z"))
        await phone.deliver("series|Asia/Shanghai|08:00|daily", at: Fixtures.instant("2026-03-02T00:00:00Z"))
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-02T00:10:00Z"))
        await phone.deliver("followup|Asia/Shanghai|2026-03-02|08:00|+15", at: Fixtures.instant("2026-03-02T00:15:00Z"))
        let before = await (phone.pending.values.map(\.text) + phone.shown.values.compactMap(\.text)).map(\.body)
        #expect(before.contains("Zinc, Iron"))

        // The user archives Iron. The run after the save leaves no request and no notification that names it.
        await phone.archive("Iron")
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-02T00:16:00Z"))
        let pending = await phone.pending.values.map(\.text.body)
        let shown = await phone.shown.values.compactMap(\.text?.body)
        #expect(!pending.isEmpty)
        #expect(!pending.contains { $0.contains("Iron") })
        #expect(!shown.contains { $0.contains("Iron") })
    }

    /// The system drops the replacement twice. The run still ends with the new request and not with the old names or none.
    @Test func aReplacementThatTheSystemDropsIsAddedAgainInTheSameRun() async throws {
        let phone = Phone()
        let series = ReminderEngine(source: phone, center: phone, privacy: phone)
        let followUps = FollowUpEngine(source: phone, center: phone, privacy: phone)
        _ = await phone.save(name: "Zinc")
        _ = await phone.save(name: "Iron")
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-01T23:30:00Z"))

        // 07:59: the user archives Iron. The first add and the second add of the series request are dropped.
        await phone.archive("Iron")
        await phone.drop(2)
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-01T23:59:00Z"))
        let daily = await phone.pending["series|Asia/Shanghai|08:00|daily"]
        #expect(daily?.text.body == "Zinc")
    }

    /// A device series and a fixed zone that equals the device zone share one request. A record closes a dose of the
    /// day before, and a reminder that the system delivered after midnight belongs to that day.
    @Test func aDeliveredReminderKeepsItsItemsInAnyOrderAndItsPlannedDate() async throws {
        let phone = Phone()
        let series = ReminderEngine(source: phone, center: phone, privacy: phone)
        let followUps = FollowUpEngine(source: phone, center: phone, privacy: phone)
        _ = await phone.save(name: "Zinc", timeZonePolicy: .followsDevice, hour: 23)
        let iron = await phone.save(name: "Iron", hour: 23)
        // 2 March 2026 is a Monday. The reminder of 23:00 is delivered at 00:01 on Tuesday, Shanghai time.
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-02T14:30:00Z"))
        await phone.deliver("series|device|23:00|daily", at: Fixtures.instant("2026-03-02T16:01:00Z"))
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-02T16:02:00Z"))
        #expect(await phone.shown.values.compactMap(\.text?.body) == ["Zinc, Iron"])

        // Monday's dose of Iron is recorded. Tuesday's dose is still open, and the notification must not follow it.
        await phone.record(OccurrenceKey(slotID: iron.slots[0].id, plannedDate: Fixtures.date(2026, 3, 2)))
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-02T16:05:00Z"))
        #expect(await phone.shown.isEmpty)
    }

    /// With notifications off, a stale pending request must go too: it would fire when the user turns them on.
    @Test func aStaleRequestGoesAlsoWhileNotificationsAreOff() async throws {
        let phone = Phone()
        let series = ReminderEngine(source: phone, center: phone, privacy: phone)
        let followUps = FollowUpEngine(source: phone, center: phone, privacy: phone)
        _ = await phone.save(name: "Zinc")
        _ = await phone.save(name: "Iron")
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-01T23:30:00Z"))
        await phone.deny()
        await phone.archive("Iron")
        try await run(phone, series, followUps, at: Fixtures.instant("2026-03-01T23:40:00Z"))
        #expect(await !phone.pending.values.contains { $0.text.body.contains("Iron") })
    }
}
