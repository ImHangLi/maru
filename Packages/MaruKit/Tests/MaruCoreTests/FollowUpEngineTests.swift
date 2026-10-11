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

    func followUpPlan(setting: FollowUpSetting?, privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone) -> FollowUpPlan {
        FollowUpPlan(
            setting: setting,
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

    nonisolated func load() -> FollowUpSetting? { FollowUpSetting(count: .one, interval: .minutes30) }
    nonisolated func save(_ setting: FollowUpSetting?) {}
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

    @Test func followUpsComeAtTheIntervalAndStopAtTheCountTheNextDoseAndTheEndOfTheDay() {
        // One item at 08:00 and 12:00, and one item at 23:00. 07:00 in Shanghai on 2 March.
        let twice = Fixtures.item()
        let late = Fixtures.item()
        let items = [twice, late]
        let schedules = [
            Fixtures.schedule(itemID: twice.id, times: [Fixtures.time(8), Fixtures.time(12)]),
            Fixtures.schedule(itemID: late.id, times: [Fixtures.time(23)]),
        ]
        let now = Fixtures.instant("2026-03-01T23:00:00Z")
        /// The follow-ups of 2 March at each slot time, as minutes after the slot time.
        func minutes(_ count: FollowUpCount, _ interval: FollowUpInterval) -> [String: [Int]] {
            let plan = FollowUpPlan(
                setting: FollowUpSetting(count: count, interval: interval),
                reminders: ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: Fixtures.shanghai),
                items: items, schedules: schedules, stored: [], closed: [], now: now, deviceTimeZone: Fixtures.shanghai
            )
            var result: [String: [Int]] = [:]
            for request in plan.requests where request.userInfo[FollowUpRequest.plannedDateKey] == "2026-03-02" {
                let time = String(request.threadIdentifier.suffix(5))
                let slot = Fixtures.instant("2026-03-02T00:00:00Z").addingTimeInterval((Double(time.prefix(2))! - 8) * 3_600)
                result[time, default: []].append(Int(request.fireDate.timeIntervalSince(slot) / 60))
            }
            return result
        }

        // A count: three follow-ups, one hour apart. 23:00 gets none, because 00:00 is the next day.
        #expect(minutes(.three, .minutes60) == ["08:00": [60, 120, 180], "12:00": [60, 120, 180]])
        // "Until Recorded": 08:00 stops before the 12:00 dose of the same item, 12:00 stops at the limit of 12,
        // and 23:00 stops at the end of the day.
        #expect(minutes(.untilRecorded, .minutes30) == [
            "08:00": Array(1...7).map { $0 * 30 }, "12:00": Array(1...12).map { $0 * 30 }, "23:00": [30],
        ])
    }

    @Test func followUpsShareTheRoomThatTheSeriesRequestsLeave() throws {
        // Eight slot times on six weekdays use the 48 series requests. 07:00 in Shanghai on Monday 2 March.
        let item = Fixtures.item()
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let schedule = Fixtures.schedule(
            itemID: item.id, times: (8...15).map { Fixtures.time($0) }, weeklyRule: try WeeklyRule(weekdays: weekdays)
        )
        let now = Fixtures.instant("2026-03-01T23:00:00Z")
        let reminders = ReminderPlan(items: [item], schedules: [schedule], now: now, deviceTimeZone: Fixtures.shanghai)
        let plan = FollowUpPlan(
            setting: FollowUpSetting(count: .untilRecorded, interval: .minutes10),
            reminders: reminders, items: [item], schedules: [schedule], stored: [], closed: [],
            now: now, deviceTimeZone: Fixtures.shanghai
        )

        // Every series request keeps its room, and the follow-ups get the other 14.
        #expect(reminders.requests.count == ReminderPlan.requestBudget)
        #expect(plan.requests.count == ReminderPlan.systemLimit - FollowUpPlan.reserve - ReminderPlan.requestBudget)
        // Each slot time of today wants five or more. Each one gets its first, then the six nearest get a second.
        let counts = Dictionary(grouping: plan.requests, by: \.threadIdentifier).mapValues(\.count)
        #expect(counts.count == 8)
        #expect(counts.values.sorted() == [1, 1, 2, 2, 2, 2, 2, 2])
        #expect(counts["followup|Asia/Shanghai|2026-03-02|15:00"] == 1)
    }
}
