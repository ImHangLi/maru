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

    /// An alarm that the system does not schedule must not leave the item with no reminder (D079).
    @Test func anAlarmThatTheSystemRefusesGivesTheItemItsNormalReminderBack() async throws {
        /// Refuses the alarm of the second day, and holds the others.
        actor Refusing: AlarmCenter, AlarmSource {
            let plan: AlarmPlan
            var held: Set<UUID> = []
            init(plan: AlarmPlan) { self.plan = plan }
            func waiting() async -> Set<UUID> { held }
            func schedule(_ request: AlarmRequest) async throws {
                if request.id == plan.requests[1].id { throw CocoaError(.fileWriteOutOfSpace) }
                held.insert(request.id)
            }
            func cancel(_ ids: [UUID]) async { held.subtract(ids) }
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
