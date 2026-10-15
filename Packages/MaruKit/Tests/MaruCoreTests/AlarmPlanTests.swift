import Foundation
import Testing
@testable import MaruCore

@Suite("Alarm plan (D079)")
struct AlarmPlanTests {
    private let now = Fixtures.instant("2026-03-02T00:05:00Z")

    private func plan(
        items: [Item], schedules: [Schedule], closed: Set<OccurrenceKey> = [], alarms: AlarmCover = AlarmCover(rings: true)
    ) -> (alarms: AlarmPlan, reminders: ReminderPlan) {
        let reminders = ReminderPlan(
            items: items, schedules: schedules, now: now, deviceTimeZone: Fixtures.shanghai, closed: closed, alarms: alarms
        )
        let alarms = AlarmPlan(
            reminders: reminders, items: items, schedules: schedules, stored: [], closed: closed,
            now: now, deviceTimeZone: Fixtures.shanghai
        )
        return (alarms, reminders)
    }

    @Test func anAlarmReplacesTheBannerAndAFollowUpStaysANotification() {
        let zinc = Fixtures.item(name: "Zinc", followUp: FollowUpSetting(count: .one, interval: .minutes15), alarm: true)
        let zincSchedule = Fixtures.schedule(itemID: zinc.id, times: [Fixtures.time(8)])
        let result = plan(items: [zinc], schedules: [zincSchedule])

        // One alarm for each of the next days, at 08:00 in Shanghai, with the "Taken" button for the one item.
        let first = result.alarms.requests[0]
        #expect(first.fireDate == Fixtures.instant("2026-03-03T00:00:00Z"))
        #expect(first.names == ["Zinc"])
        #expect(first.taken?[FollowUpRequest.itemIDKey] == zinc.id.rawValue.uuidString)
        // The item has no series request. Its follow-ups still come.
        #expect(result.reminders.requests.isEmpty)
        let followUps = FollowUpPlan(
            reminders: result.reminders, items: [zinc], schedules: [zincSchedule], stored: [], closed: [],
            now: now, deviceTimeZone: Fixtures.shanghai
        )
        #expect(!followUps.requests.isEmpty)

        // With no permission for alarms, the item gets its normal reminder and no alarm.
        let denied = plan(items: [zinc], schedules: [zincSchedule], alarms: .none)
        #expect(denied.alarms.requests.isEmpty)
        #expect(!denied.reminders.requests.isEmpty)
    }

    @Test func aRecordedDoseHasNoAlarmAndAnItemAtTheSameTimeLosesTheTakenButton() {
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let iron = Fixtures.item(name: "Iron")
        let zincSchedule = Fixtures.schedule(itemID: zinc.id, times: [Fixtures.time(8)])
        let ironSchedule = Fixtures.schedule(itemID: iron.id, times: [Fixtures.time(8)])
        let both = plan(items: [zinc, iron], schedules: [zincSchedule, ironSchedule])
        // The alarm names only its own item. Iron keeps its banner. A second item at the time means no "Taken" button.
        #expect(both.alarms.requests[0].names == ["Zinc"])
        #expect(both.alarms.requests[0].taken == nil)
        #expect(both.reminders.requests.count == 1)

        // The user records tomorrow's dose in advance: that dose has no alarm.
        let key = OccurrenceKey(slotID: zincSchedule.slots[0].id, plannedDate: Fixtures.date(2026, 3, 3))
        let recorded = plan(items: [zinc, iron], schedules: [zincSchedule, ironSchedule], closed: [key])
        #expect(recorded.alarms.requests.count == both.alarms.requests.count - 1)
        #expect(!recorded.alarms.requests.contains { $0.fireDate == Fixtures.instant("2026-03-03T00:00:00Z") })
    }

    /// N2 (D089): an item that follows the device and has no day cycle gets one repeating alarm, which never runs out.
    @Test func aDeviceFollowingWeeklyItemGetsOneRepeatingAlarm() throws {
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let schedule = Fixtures.schedule(
            itemID: zinc.id, times: [Fixtures.time(8)], weeklyRule: try WeeklyRule(weekdays: [.monday, .thursday]),
            timeZonePolicy: .followsDevice
        )
        let requests = plan(items: [zinc], schedules: [schedule]).alarms.requests
        #expect(requests.count == 1)
        let repeating = try #require(requests[0].repeating)
        #expect(repeating.weekdays == [.monday, .thursday] && repeating.time == Fixtures.time(8))
        // The first ring is the next one. The button has no date, so the app finds it when the button runs.
        #expect(requests[0].fireDate == Fixtures.instant("2026-03-05T00:00:00Z"))
        #expect(requests[0].taken?[FollowUpRequest.itemIDKey] == zinc.id.rawValue.uuidString)
        #expect(requests[0].taken?[FollowUpRequest.plannedDateKey] == nil)

        // A record before the time of one day takes that weekday out of the repeat. Its dates keep their alarms.
        let key = OccurrenceKey(slotID: schedule.slots[0].id, plannedDate: Fixtures.date(2026, 3, 5))
        let recorded = plan(items: [zinc], schedules: [schedule], closed: [key]).alarms.requests
        #expect(recorded.filter { $0.repeating != nil }.map { $0.repeating!.weekdays } == [[.monday]])
        #expect(recorded.filter { $0.repeating == nil }.count == 3)
    }

    @Test func theButtonOfARepeatingAlarmFindsTodaysDoseOnlyAfterItsTime() {
        // 08:05 on 2 March in Shanghai.
        #expect(AlarmRequest.plannedDate(ofSeries: "series|device|08:00", at: now, deviceTimeZone: Fixtures.shanghai) == "2026-03-02")
        #expect(AlarmRequest.plannedDate(ofSeries: "series|device|09:00", at: now, deviceTimeZone: Fixtures.shanghai) == nil)
        #expect(AlarmRequest.plannedDate(ofSeries: "series|Asia/Shanghai|08:00", at: now, deviceTimeZone: Fixtures.shanghai) == nil)
    }

    /// An edit of the amount changes the schedule version. The "Taken" button carries the version, so the alarm must be new (D089).
    @Test func anAlarmHasANewIdentityWhenTheScheduleVersionChanges() throws {
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let first = Fixtures.schedule(itemID: zinc.id, times: [Fixtures.time(8)], timeZonePolicy: .followsDevice)
        var edited = first
        let latest = try #require(first.versions.last)
        try edited.appendVersion(
            ScheduleVersion(
                scheduleID: first.id, effectiveFrom: Fixtures.date(2026, 3, 1), weeklyRule: latest.weeklyRule,
                slotTimes: latest.slotTimes, dose: Dose("2 capsules"), timeZonePolicy: .followsDevice
            )
        )
        let before = plan(items: [zinc], schedules: [first]).alarms.requests
        let after = plan(items: [zinc], schedules: [edited]).alarms.requests
        #expect(before.map(\.id) != after.map(\.id))
    }

    /// The limit wins: the id stops being wanted in the same step, so a late answer is cancelled (D089).
    @Test func aScheduleThatAnswersJustAfterTheLimitIsCancelled() async throws {
        actor Slow: AlarmCenter {
            var cancelled: [UUID] = []
            func waiting() async -> Set<UUID> { [] }
            func schedule(_ request: AlarmRequest) async throws { try await Task.sleep(for: .milliseconds(120)) }
            func cancel(_ ids: [UUID]) async throws { cancelled += ids }
        }
        let slow = Slow()
        let wanted = WantedAlarms()
        let center = TimedAlarmCenter(base: slow, wanted: wanted, limit: .milliseconds(40))
        let request = AlarmRequest(id: UUID(), fireDate: now, itemIDs: [], names: nil, taken: nil)
        wanted.insert(request.id)
        await #expect(throws: AlarmRunError.self) { try await center.schedule(request) }
        // The caller does nothing. The limit alone made the id unwanted.
        #expect(!wanted.isWanted(request.id))
        try await Task.sleep(for: .milliseconds(300))
        let cancelled = await slow.cancelled
        #expect(cancelled == [request.id])
    }

    /// A "Stop" between two reads can hide a repeating alarm from both. The engine reads one snapshot (D089).
    @Test func theEngineReadsOneSnapshotOfTheAlarms() async throws {
        actor Racing: AlarmCenter, AlarmSource {
            let plan: AlarmPlan
            var scheduled = 0
            init(plan: AlarmPlan) { self.plan = plan }
            // The two separate reads both miss the alarm. Only the snapshot has it.
            func waiting() async -> Set<UUID> { [] }
            func active() async -> Set<UUID> { [] }
            func snapshot() async -> AlarmSnapshot { AlarmSnapshot(waiting: [], active: [plan.requests[0].id.withGeneration(1)]) }
            func schedule(_ request: AlarmRequest) async throws { scheduled += 1 }
            func cancel(_ ids: [UUID]) async throws {}
            func alarmPlan(privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover) async throws -> AlarmPlan { plan }
        }
        struct Names: ReminderPrivacyStore {
            func load() -> ReminderPrivacy { .showNames }
            func save(_ privacy: ReminderPrivacy) {}
        }
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let schedule = Fixtures.schedule(itemID: zinc.id, times: [Fixtures.time(8)], timeZonePolicy: .followsDevice)
        let center = Racing(plan: plan(items: [zinc], schedules: [schedule]).alarms)
        _ = try await AlarmEngine(source: center, center: center, privacy: Names(), alarmsRing: { true })
            .refresh(at: now, deviceTimeZone: Fixtures.shanghai)
        let scheduled = await center.scheduled
        #expect(scheduled == 0)
    }

    /// N3 (D089): the limit cut doses that are due soon, and the item did not know. Now it gets its banner back.
    @Test func aDoseThatTheLimitCutGivesItsItemTheBannerBack() throws {
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let times = (6..<16).map { Fixtures.time($0) }
        let schedule = Fixtures.schedule(itemID: zinc.id, times: times)
        let result = plan(items: [zinc], schedules: [schedule])
        #expect(result.alarms.requests.count == AlarmPlan.limit)
        #expect(result.alarms.cutItems == [zinc.id])
    }

    /// An alarm that the system does not schedule must not leave the item with no reminder (D079).
    @Test func anAlarmThatTheSystemRefusesGivesTheItemItsNormalReminderBack() async throws {
        /// Refuses the alarm of the second day, and holds the others.
        actor Refusing: AlarmCenter, AlarmSource {
            let plan: AlarmPlan
            var held: Set<UUID> = []
            init(plan: AlarmPlan) { self.plan = plan }
            func waiting() async -> Set<UUID> { held }
            func schedule(_ request: AlarmRequest) async throws {
                if request.id.alarmContent == plan.requests[1].id { throw CocoaError(.fileWriteOutOfSpace) }
                held.insert(request.id)
            }
            func cancel(_ ids: [UUID]) async throws { held.subtract(ids) }
            func alarmPlan(privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarms: AlarmCover) async throws -> AlarmPlan { plan }
        }
        struct Names: ReminderPrivacyStore {
            func load() -> ReminderPrivacy { .showNames }
            func save(_ privacy: ReminderPrivacy) {}
        }
        let zinc = Fixtures.item(name: "Zinc", alarm: true)
        let schedule = Fixtures.schedule(itemID: zinc.id, times: [Fixtures.time(8)])
        let phone = Refusing(plan: plan(items: [zinc], schedules: [schedule]).alarms)
        let failed = try await AlarmEngine(source: phone, center: phone, privacy: Names(), alarmsRing: { true })
            .refresh(at: now, deviceTimeZone: Fixtures.shanghai)
        #expect(failed == [zinc.id])
        // One alarm failed, so the item holds no other alarm: a dose never gets an alarm and a banner together.
        #expect(await phone.held.isEmpty)

        // The next notification run sees the failure and sets the banner.
        let covered = plan(items: [zinc], schedules: [schedule], alarms: AlarmCover(rings: true, failed: failed))
        #expect(!covered.reminders.requests.isEmpty)
    }
}
