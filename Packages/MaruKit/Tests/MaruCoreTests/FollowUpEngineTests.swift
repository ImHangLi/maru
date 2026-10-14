import Foundation
import Testing
@testable import MaruCore

/// The saved plan, the records, the setting, and the notification system of a test. Removals complete in the call.
private actor FollowUpPhone: FollowUpSource, FollowUpCenter, RemovalLedger, ReminderPrivacyStore {
    var items: [Item] = []
    var schedules: [Schedule] = []
    var stored: [StoredOccurrence] = []
    var closed: Set<OccurrenceKey> = []
    var pending: [String: [String: String]] = [:]
    var texts: [String: ReminderText] = [:]
    private var actions: Set<String> = []
    var shown: [String: ReminderText] = [:]

    func save(
        times: [Int], timeZonePolicy: TimeZonePolicy = .fixed(Fixtures.shanghai),
        followUp: FollowUpSetting? = FollowUpSetting(count: .one, interval: .minutes30), name: String = "Vitamin D"
    ) -> Schedule {
        let item = Fixtures.item(name: name, followUp: followUp)
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

    func followUpPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover
    ) -> FollowUpPlan {
        FollowUpPlan(
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

    nonisolated func load() -> Set<String> { [] }
    nonisolated func save(_ identifiers: Set<String>) {}
    nonisolated func load() -> ReminderPrivacy { .showNames }
    nonisolated func save(_ privacy: ReminderPrivacy) {}
    nonisolated func text(for content: ReminderContent) -> ReminderText { Fixtures.text(for: content) }
}

@Suite("Follow-up reminder (spec 4, 8.2, D021, D039)")
struct FollowUpEngineTests {
    @Test func recordedOccurrenceHasNoPendingOrDeliveredFollowUpAfterARefresh() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, privacy: phone)
        let schedule = await phone.save(times: [8, 20])
        let today = Fixtures.date(2026, 3, 2)

        // 08:20 in Shanghai. The 08:00 follow-up comes at 08:30.
        _ = try await engine.refresh(at: Fixtures.instant("2026-03-02T00:20:00Z"), deviceTimeZone: Fixtures.shanghai)
        let morning = "followup|Asia/Shanghai|2026-03-02|08:00|+30"
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
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-02|20:00|+30"))
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-03|08:00|+30"))
    }

    @Test func deliveredFollowUpThatNamesARecordedItemIsRemoved() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, privacy: phone)
        let first = await phone.save(times: [8])
        _ = await phone.save(times: [8])
        let morning = "followup|Asia/Shanghai|2026-03-02|08:00|+30"
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
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, privacy: phone)
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
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-02|08:00|+30"))
        #expect(!pending.keys.contains("followup|Asia/Shanghai|2026-03-02|09:00|+30"))
        #expect(pending.keys.contains("followup|Asia/Shanghai|2026-03-03|09:00|+30"))
    }

    @Test func deviceSeriesInTwoZonesKeepsTheFutureFollowUp() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, privacy: phone)
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
        #expect(pending.keys.contains("followup|device@America/Chicago|2026-03-02|08:00|+30"))
        #expect(!pending.keys.contains("followup|device@America/New_York|2026-03-02|08:00|+30"))
    }

    @Test func eachItemKeepsItsOwnSettingAndItemsAtOneInstantShareARequest() async throws {
        let phone = FollowUpPhone()
        let engine = FollowUpEngine(source: phone, center: phone, ledger: phone, privacy: phone)
        // Three items at 08:00 in Shanghai: one reminds 2 times every 15 minutes, one 1 time every 30 minutes, one never.
        _ = await phone.save(times: [8], followUp: FollowUpSetting(count: .two, interval: .minutes15), name: "Zinc")
        _ = await phone.save(times: [8], followUp: FollowUpSetting(count: .one, interval: .minutes30), name: "Iron")
        _ = await phone.save(times: [8], followUp: nil, name: "Iodine")
        let now = Fixtures.instant("2026-03-02T00:05:00Z")
        _ = try await engine.refresh(at: now, deviceTimeZone: Fixtures.shanghai)

        // Of today's dose: +15 names Zinc, and +30 is one request for Zinc and Iron. Iodine is never named.
        let group = "followup|Asia/Shanghai|2026-03-02|08:00"
        let today = await phone.pending.keys.filter { $0.hasPrefix(group) }.sorted()
        #expect(today == [group + "|+15", group + "|+30"])
        #expect(await phone.texts[group + "|+15"]?.body == "Zinc")
        #expect(await phone.texts[group + "|+30"]?.body == "Zinc, Iron")
    }

    @Test func aChangeOfTheSettingKeepsTheLimitOfTheDose() {
        // One item at 08:00 in Shanghai. "Until Recorded" every 30 minutes, changed at a time after the slot.
        let slot = Fixtures.instant("2026-03-02T00:00:00Z")
        /// The follow-ups of the 08:00 dose on 2 March, as minutes after 08:00, when the setting of the item
        /// changed `seconds` after 08:00.
        func minutes(changedAt seconds: Double) -> [Int] {
            let now = slot.addingTimeInterval(seconds)
            let item = Fixtures.item(
                followUp: FollowUpSetting(count: .untilRecorded, interval: .minutes30), followUpChanged: now
            )
            let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
            let plan = FollowUpPlan(
                reminders: ReminderPlan(items: [item], schedules: [schedule], now: now, deviceTimeZone: Fixtures.shanghai),
                items: [item], schedules: [schedule], stored: [], closed: [], now: now, deviceTimeZone: Fixtures.shanghai
            )
            return plan.requests.filter { $0.threadIdentifier == "followup|Asia/Shanghai|2026-03-02|08:00" }
                .map { Int($0.fireDate.timeIntervalSince(slot) / 60) }
        }

        // The change is at 08:59:59.8: 11 old ones came, and one new one comes.
        #expect(minutes(changedAt: 3_599.9) == [60])
        // The change is just after 09:00: 12 came, so no new one comes.
        #expect(minutes(changedAt: 3_600.5) == [])
        // The change is at 08:31: at most 6 came, so 6 come every 30 minutes.
        #expect(minutes(changedAt: 1_860) == [60, 90, 120, 150, 180, 210])
    }
}
