import Foundation
import Testing
@testable import MaruCore

@Suite("Notification tap (spec 8.3, T15, T24)")
struct ReminderTapTests {
    private let item = Fixtures.item()
    private var schedule: Schedule { Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)]) }

    private static let apia = try! NamedTimeZone(identifier: "Pacific/Apia")
    private static let pagoPago = try! NamedTimeZone(identifier: "Pacific/Pago_Pago")

    /// The first 08:00 request of the registered plan as the system delivers it, with its `userInfo` and trigger weekday.
    private func reminder(
        deliveredAt: String, items: [Item]? = nil, schedules: [Schedule], deviceTimeZone: NamedTimeZone = Fixtures.shanghai
    ) -> DeliveredReminder {
        let plan = ReminderPlan(
            items: items ?? [item], schedules: schedules, now: Fixtures.instant("2026-03-01T00:00:00Z"), deviceTimeZone: deviceTimeZone
        )
        let request = plan.requests[0]
        return DeliveredReminder(
            deliveredAt: Fixtures.instant(deliveredAt),
            userInfo: request.userInfo,
            triggerWeekday: request.trigger.dateComponents.weekday.flatMap(Weekday.init(calendarWeekday:))
        )
    }

    private func reminder(deliveredAt: String, schedule: Schedule) -> DeliveredReminder {
        reminder(deliveredAt: deliveredAt, schedules: [schedule])
    }

    private func tap(
        _ reminder: DeliveredReminder,
        at now: String,
        items: [Item]? = nil,
        schedules: [Schedule],
        deviceTimeZone: NamedTimeZone = Fixtures.shanghai,
        observed: ObservedTimeZone? = nil
    ) -> ReminderTapResolution {
        ReminderTapResolver(now: Fixtures.instant(now), deviceTimeZone: deviceTimeZone, observedTimeZone: observed)
            .resolve(reminder, items: items ?? [item], schedules: schedules)
    }

    private func tap(_ reminder: DeliveredReminder, at now: String, schedule: Schedule) -> ReminderTapResolution {
        tap(reminder, at: now, schedules: [schedule])
    }

    @Test func oldReminderTappedOnTheNextDayOffersItsOwnDateAndNotToday() {
        let schedule = schedule
        // Delivered at 08:00 in Shanghai on 2 March.
        let delivered = reminder(deliveredAt: "2026-03-02T00:00:00Z", schedule: schedule)

        guard case let .resolved(sameDay) = tap(delivered, at: "2026-03-02T01:00:00Z", schedule: schedule) else {
            Issue.record("A tap on the same day must resolve")
            return
        }
        #expect(sameDay.map(\.plannedDate) == [Fixtures.date(2026, 3, 2)])

        // T15: tapped at 09:00 on 3 March. The candidate is the occurrence of 2 March, and the user confirms it.
        guard case let .confirm(candidates, doubts) = tap(delivered, at: "2026-03-03T01:00:00Z", schedule: schedule) else {
            Issue.record("A tap on another day must ask for a confirmation")
            return
        }
        #expect(doubts == [.otherDay])
        #expect(candidates.map(\.plannedDate) == [Fixtures.date(2026, 3, 2)])
    }

    @Test func delayedDeliveryAsksAndDoesNotChooseADate() {
        let schedule = schedule
        // The 08:00 reminder arrives at 10:30 in Shanghai, and the user taps it at once (T24).
        let delivered = reminder(deliveredAt: "2026-03-02T02:30:00Z", schedule: schedule)

        guard case let .confirm(candidates, doubts) = tap(delivered, at: "2026-03-02T02:30:00Z", schedule: schedule) else {
            Issue.record("A delayed reminder must ask for a confirmation")
            return
        }
        #expect(doubts.contains(.delayed))
        #expect(candidates.map(\.plannedDate) == [Fixtures.date(2026, 3, 2), Fixtures.date(2026, 3, 1)])
        // The candidates have the planned time, not the delivery time or the tap time.
        #expect(candidates.allSatisfy { $0.plannedTime == Fixtures.time(8) })
    }

    @Test func weeklyReminderDeliveredNearAnotherWeekdayDoesNotResolveToThatWeekday() {
        let other = Fixtures.item()
        let monday = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)], weeklyRule: try! WeeklyRule(weekdays: [.monday]))
        let tuesday = Fixtures.schedule(itemID: other.id, times: [Fixtures.time(8)], weeklyRule: try! WeeklyRule(weekdays: [.tuesday]))
        // The Monday 08:00 request (2 March) arrives at 08:02 on Tuesday 3 March, near the time of the Tuesday item.
        let delivered = reminder(deliveredAt: "2026-03-03T00:02:00Z", items: [item, other], schedules: [monday, tuesday])

        guard case let .confirm(candidates, _) = tap(
            delivered, at: "2026-03-03T00:03:00Z", items: [item, other], schedules: [monday, tuesday]
        ) else {
            Issue.record("A weekly request must not resolve to a date of another weekday")
            return
        }
        #expect(candidates.map(\.plannedDate) == [Fixtures.date(2026, 3, 2), Fixtures.date(2026, 2, 23)])
    }

    @Test func followUpAfterMidnightTakesTheDoseOfTheDayBeforeUntilOneOClock() throws {
        let item = Fixtures.item(followUp: FollowUpSetting(count: .one, interval: .minutes30))
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(23, 30)])
        // The follow-up of the 23:30 dose of 1 March comes at 00:00 on 2 March in Shanghai.
        let now = Fixtures.instant("2026-03-01T15:00:00Z")
        let plan = FollowUpPlan(
            reminders: ReminderPlan(items: [item], schedules: [schedule], now: now, deviceTimeZone: Fixtures.shanghai),
            items: [item], schedules: [schedule], stored: [], closed: [], now: now, deviceTimeZone: Fixtures.shanghai
        )
        let request = try #require(plan.requests.first { $0.threadIdentifier == "followup|Asia/Shanghai|2026-03-01|23:30" })
        let delivered = DeliveredReminder(deliveredAt: request.fireDate, userInfo: request.userInfo, triggerWeekday: nil)
        func target(at now: String) -> PlannedOccurrence? {
            ReminderTapResolver(now: Fixtures.instant(now), deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil)
                .actionDoses(of: delivered, items: [item], schedules: [schedule]).doses.first
        }

        // At 00:10 the "Taken" action records the dose of 1 March, not a dose of 2 March.
        #expect(target(at: "2026-03-01T16:10:00Z")?.plannedDate == Fixtures.date(2026, 3, 1))
        // At 01:10 it records nothing, and a tap asks the user.
        #expect(target(at: "2026-03-01T17:10:00Z") == nil)
    }

    @Test func deviceZoneChangeAfterTheDeliveryAsksForTheDate() {
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)], timeZonePolicy: .followsDevice)
        // Delivered at 08:00 on 2 March in Apia. The engine saw Apia since before the delivery.
        let delivered = reminder(deliveredAt: "2026-03-01T19:00:00Z", schedules: [schedule], deviceTimeZone: Self.apia)
        let observed = ObservedTimeZone(timeZone: Self.apia, since: Fixtures.instant("2026-03-01T00:00:00Z"))

        let inApia = tap(delivered, at: "2026-03-01T19:05:00Z", schedules: [schedule], deviceTimeZone: Self.apia, observed: observed)
        guard case let .resolved(sameZone) = inApia else {
            Issue.record("A tap in the zone of the delivery must resolve")
            return
        }
        #expect(sameZone.map(\.plannedDate) == [Fixtures.date(2026, 3, 2)])

        // The device then moves to Pago Pago, where the delivery instant is 1 March 08:00.
        guard case let .confirm(candidates, doubts) = tap(
            delivered, at: "2026-03-01T19:05:00Z", schedules: [schedule], deviceTimeZone: Self.pagoPago, observed: observed
        ) else {
            Issue.record("A tap after a zone change must ask for a confirmation")
            return
        }
        #expect(doubts.contains(.zoneChange))
        #expect(candidates.map(\.plannedDate).contains(Fixtures.date(2026, 3, 2)))
    }
}
