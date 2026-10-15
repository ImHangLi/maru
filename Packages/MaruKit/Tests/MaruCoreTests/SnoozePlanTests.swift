import Foundation
import Testing
@testable import MaruCore

@Suite("Snooze in the follow-up plan (D090)")
struct SnoozePlanTests {
    private let item = Fixtures.item(followUp: FollowUpSetting(count: .three, interval: .minutes5))
    private let schedule: Schedule
    private let slot: ScheduleSlotID

    init() {
        let item = item
        var schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
        slot = schedule.slots[0].id
        schedule.isEnabled = true
        self.schedule = schedule
    }

    private func plan(snoozes: [SnoozeEntry], closed: Set<OccurrenceKey> = [], now: String = "2026-03-01T00:01:00Z") -> FollowUpPlan {
        let now = Fixtures.instant(now)
        return FollowUpPlan(
            reminders: ReminderPlan(items: [item], schedules: [schedule], now: now, deviceTimeZone: Fixtures.shanghai, closed: closed),
            items: [item], schedules: [schedule], stored: [], closed: closed, now: now, deviceTimeZone: Fixtures.shanghai,
            snoozes: snoozes
        )
    }

    @Test func aSnoozedGroupGetsOneRequestAtItsTimeAndItsFollowUpsWait() throws {
        // The dose is at 08:00 in Shanghai, which is 00:00 UTC. The user snoozes at 08:01 until 08:11.
        let entry = SnoozeEntry(seriesID: "series|Asia/Shanghai|08:00", plannedDate: "2026-03-01", fireAt: Fixtures.instant("2026-03-01T00:11:00Z"))
        let plan = plan(snoozes: [entry])

        let today = plan.requests.filter { $0.threadIdentifier == "followup|Asia/Shanghai|2026-03-01|08:00" }
        #expect(today.map(\.identifier) == [
            "followup|Asia/Shanghai|2026-03-01|08:00|snooze", "followup|Asia/Shanghai|2026-03-01|08:00|+15",
        ])
        #expect(today[0].fireDate == entry.fireAt && today[0].content.names == ["Vitamin D"] && today[0].content.kind == .due)
        #expect(today[0].content.category == .single)
        #expect(plan.standingSnoozes == [entry])
        // After its time, the entry still stands, and it keeps the text of the delivered snooze. It adds no request.
        let later = self.plan(snoozes: [entry], now: "2026-03-01T00:12:00Z")
        #expect(later.requests.filter { $0.identifier.hasSuffix("|snooze") }.isEmpty)
        #expect(later.open["followup|Asia/Shanghai|2026-03-01|08:00|snooze"] != nil && later.standingSnoozes == [entry])
    }

    @Test func aClosedGroupHasNoSnoozeRequestAndItsEntryDoesNotStand() {
        let entry = SnoozeEntry(seriesID: "series|Asia/Shanghai|08:00", plannedDate: "2026-03-01", fireAt: Fixtures.instant("2026-03-01T00:11:00Z"))
        let plan = plan(snoozes: [entry], closed: [OccurrenceKey(slotID: slot, plannedDate: Fixtures.date(2026, 3, 1))])

        #expect(plan.requests.filter { $0.identifier.hasSuffix("|snooze") }.isEmpty)
        #expect(plan.standingSnoozes.isEmpty)
    }
}
