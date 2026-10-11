import Foundation
import Testing
@testable import MaruCore

/// The saved plan, the records, the setting, and the notification system of a test. Removals complete in the call.
private actor FollowUpPhone: FollowUpSource, FollowUpCenter, FollowUpSettingStore, RemovalLedger, ReminderPrivacyStore {
    var items: [Item] = []
    var schedules: [Schedule] = []
    var stored: [StoredOccurrence] = []
    var closed: Set<OccurrenceKey> = []
    var pending: [String: [String: String]] = [:]
    private var texts: [String: ReminderText] = [:]
    private var actions: Set<String> = []
    var shown: [String: ReminderText] = [:]

    func save(times: [Int], timeZonePolicy: TimeZonePolicy = .fixed(Fixtures.shanghai)) -> Schedule {
        let item = Fixtures.item()
        items.append(item)
        let schedule = Fixtures.schedule(itemID: item.id, times: times.map { Fixtures.time($0) }, timeZonePolicy: timeZonePolicy)
        schedules.append(schedule)
        return schedule
    }

    func replace(_ schedule: Schedule) {
        schedules = schedules.map { $0.id == schedule.id ? schedule : $0 }
    }

    func store(_ occurrence: Occurrence, hasEvents: Bool) {
        stored.append(StoredOccurrence(occurrence: occurrence, hasEvents: hasEvents))
    }

    func record(_ key: OccurrenceKey) {
        closed.insert(key)
    }

    func deliver(_ identifier: String) {
        pending[identifier] = nil
        shown[identifier] = texts[identifier]
    }

    func followUpPlan(delay: FollowUpDelay?, privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone) -> FollowUpPlan {
        FollowUpPlan(
            delay: delay,
            reminders: ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy),
            items: items,
            schedules: schedules,
            stored: stored,
            closed: closed,
            now: now,
            deviceTimeZone: deviceTimeZone,
            privacy: privacy
        )
    }

    func authorization() -> ReminderAuthorization { .authorized }
    func requestAuthorization() -> ReminderAuthorization { .authorized }
    func pendingRequests() -> [PendingReminder] {
        pending.map {
            PendingReminder(identifier: $0.key, userInfo: $0.value, text: texts[$0.key], hasTakenAction: actions.contains($0.key))
        }
    }
    func add(_ request: ReminderRequest) {}
    func add(_ request: FollowUpRequest) {
        pending[request.identifier] = request.userInfo
        texts[request.identifier] = text(for: request.content)
        actions.remove(request.identifier)
        if request.content.hasTakenAction { actions.insert(request.identifier) }
    }
    func remove(identifiers: [String]) {
        identifiers.forEach { pending[$0] = nil }
    }
    func delivered() -> [PendingReminder] {
        shown.map { PendingReminder(identifier: $0.key, userInfo: [:], text: $0.value) }
    }
    func removeDelivered(identifiers: [String]) {
        identifiers.forEach { shown[$0] = nil }
    }

    nonisolated func load() -> FollowUpDelay? { .minutes30 }
    nonisolated func save(_ delay: FollowUpDelay?) {}
    nonisolated func load() -> Set<String> { [] }
    nonisolated func save(_ identifiers: Set<String>) {}
    nonisolated func load() -> ReminderPrivacy { .showNames }
    nonisolated func save(_ privacy: ReminderPrivacy) {}
    nonisolated func text(for content: ReminderContent) -> ReminderText { Fixtures.text(for: content) }
}

@Suite("Follow-up reminder (spec 4, 8.2, D021)")
struct FollowUpEngineTests {
    @Test func recordedOccurrenceHasNoPendingOrDeliveredFollowUpAfterARefresh() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, setting: phone, privacy: phone)
        let schedule = await phone.save(times: [8, 20])
        let today = Fixtures.date(2026, 3, 2)

        // 08:20 in Shanghai. The 08:00 follow-up comes at 08:30.
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:20:00Z"), deviceTimeZone: Fixtures.shanghai)
        let morning = "followup|Asia/Shanghai|2026-03-02|08:00"
        #expect(await phone.pending.keys.contains(morning))
        // Today 08:00 and 20:00, then two for each of the next six days, within seven days of now.
        #expect(await phone.pending.count == 14)

        // 08:40: the follow-up was delivered, then the user records the morning dose.
        await phone.deliver(morning)
        await phone.record(OccurrenceKey(slotID: schedule.slots[0].id, plannedDate: today))
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:40:00Z"), deviceTimeZone: Fixtures.shanghai)

        #expect(await phone.shown.isEmpty)
        let pending = await phone.pending
        #expect(!pending.keys.contains(morning))
        // The evening of the same day is still open, and tomorrow's morning is another occurrence.
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-02|20:00"))
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-03|08:00"))
    }

    @Test func deliveredFollowUpThatNamesARecordedItemIsRemoved() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, setting: phone, privacy: phone)
        let first = await phone.save(times: [8])
        _ = await phone.save(times: [8])
        let morning = "followup|Asia/Shanghai|2026-03-02|08:00"
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:20:00Z"), deviceTimeZone: Fixtures.shanghai)

        // The follow-up names both items. A refresh with no record keeps it.
        await phone.deliver(morning)
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:35:00Z"), deviceTimeZone: Fixtures.shanghai)
        #expect(await phone.shown.keys.contains(morning))

        // The user records one item. The other is open, and the delivered text still names both (D029).
        await phone.record(OccurrenceKey(slotID: first.slots[0].id, plannedDate: Fixtures.date(2026, 3, 2)))
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:40:00Z"), deviceTimeZone: Fixtures.shanghai)
        #expect(await phone.shown.isEmpty)
    }

    @Test func undoneOccurrenceKeepsItsStoredTimeAfterAScheduleEdit() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, setting: phone, privacy: phone)
        var schedule = await phone.save(times: [8])
        let today = Fixtures.date(2026, 3, 2)
        // The user recorded and undid the 08:00 dose, so the stored occurrence has events and no state.
        await phone.store(
            Occurrence(
                slotID: schedule.slots[0].id,
                plannedDate: today,
                plannedTime: Fixtures.time(8),
                timeZone: Fixtures.shanghai,
                scheduleVersionID: schedule.versions[0].id
            ),
            hasEvents: true
        )
        // Then the slot moves to 09:00 from today. D019 keeps the stored occurrence at 08:00.
        try schedule.changeTime(of: schedule.slots[0].id, to: Fixtures.time(9), effectiveFrom: today)
        await phone.replace(schedule)

        // 08:10 in Shanghai.
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:10:00Z"), deviceTimeZone: Fixtures.shanghai)
        let pending = await phone.pending
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-02|08:00"))
        #expect(!pending.keys.contains("followup|Asia/Shanghai|2026-03-02|09:00"))
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-03|09:00"))
    }

    @Test func deviceSeriesInTwoZonesKeepsTheFutureFollowUp() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, setting: phone, privacy: phone)
        let chicago = try NamedTimeZone(identifier: "America/Chicago")
        let undone = await phone.save(times: [8], timeZonePolicy: .followsDevice)
        _ = await phone.save(times: [8], timeZonePolicy: .followsDevice)
        let today = Fixtures.date(2026, 3, 2)
        // The user recorded and undid the 08:00 dose in New York, so the stored occurrence keeps New York.
        await phone.store(
            Occurrence(
                slotID: undone.slots[0].id,
                plannedDate: today,
                plannedTime: Fixtures.time(8),
                timeZone: Fixtures.newYork,
                scheduleVersionID: undone.versions[0].id
            ),
            hasEvents: true
        )

        // 07:40 in Chicago, 08:40 in New York. The New York follow-up passed, and the Chicago one comes at 08:30.
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T13:40:00Z"), deviceTimeZone: chicago)
        let pending = await phone.pending
        #expect(pending.keys.contains("followup|device@America/Chicago|2026-03-02|08:00"))
        #expect(!pending.keys.contains("followup|device@America/New_York|2026-03-02|08:00"))
    }
}
