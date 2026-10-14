import Foundation
import Testing
@testable import MaruCore

private final class MemoryLedger: RemovalLedger, @unchecked Sendable {
    private let lock = NSLock()
    private var identifiers: Set<String> = []
    func load() -> Set<String> { lock.withLock { identifiers } }
    func save(_ identifiers: Set<String>) { lock.withLock { self.identifiers = identifiers } }
}

/// The saved plan and the notification system of a test, for the series engine and the follow-up engine together.
/// A repeating series request stays pending after it is delivered, as in the system.
private actor Phone: ReminderPlanSource, FollowUpSource, FollowUpCenter, ReminderPrivacyStore {
    var items: [Item] = []
    var schedules: [Schedule] = []
    var pending: [String: (userInfo: [String: String], text: ReminderText)] = [:]
    var shown: [String: PendingReminder] = [:]

    func save(name: String) -> Schedule {
        let item = Fixtures.item(name: name, followUp: FollowUpSetting(count: .two, interval: .minutes15))
        items.append(item)
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
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
    func deliver(_ identifier: String, at date: Date) {
        guard let request = pending[identifier] else { return }
        shown[identifier] = PendingReminder(identifier: identifier, userInfo: request.userInfo, text: request.text, deliveredAt: date)
        if identifier.hasPrefix(FollowUpRequest.identifierPrefix) { pending[identifier] = nil }
    }

    func reminderPlan(at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover) -> ReminderPlan {
        ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy)
    }

    func followUpPlan(privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover) -> FollowUpPlan {
        FollowUpPlan(
            reminders: reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: privacy, alarms: alarms),
            items: items, schedules: schedules, stored: [], closed: [], now: now, deviceTimeZone: deviceTimeZone, privacy: privacy
        )
    }

    func confirmFollowUpChanges(at time: Date) {}
    func authorization() -> ReminderAuthorization { .authorized }
    func requestAuthorization() -> ReminderAuthorization { .authorized }
    func pendingRequests() -> [PendingReminder] {
        pending.map { PendingReminder(identifier: $0.key, userInfo: $0.value.userInfo, text: $0.value.text) }
    }
    func add(_ request: ReminderRequest) { pending[request.identifier] = (request.userInfo, text(for: request.content)) }
    func add(_ request: FollowUpRequest) { pending[request.identifier] = (request.userInfo, text(for: request.content)) }
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
        let series = ReminderEngine(source: phone, center: phone, ledger: MemoryLedger(), privacy: phone)
        let followUps = FollowUpEngine(source: phone, center: phone, ledger: MemoryLedger(), privacy: phone)
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
}
