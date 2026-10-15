import Foundation
import Testing
@testable import MaruCore

@Suite("Reminder compilation (spec 8.1, 8.2, 8.3, 8.4)")
struct ReminderPlanTests {
    /// The plan in Shanghai, on 2 March 2026 when the test gives no instant.
    private func compile(
        items: [Item],
        schedules: [Schedule],
        at now: String = "2026-03-02T00:00:00Z",
        privacy: ReminderPrivacy = .showNames,
        requestBudget: Int = ReminderPlan.requestBudget,
        longerReach: Bool = false
    ) -> ReminderPlan {
        ReminderPlan(
            items: items,
            schedules: schedules,
            now: Fixtures.instant(now),
            deviceTimeZone: Fixtures.shanghai,
            privacy: privacy,
            requestBudget: requestBudget,
            longerReach: longerReach
        )
    }

    @Test func slotsAtTheSameTimeShareOneRequest() {
        let items = [Fixtures.item(), Fixtures.item(), Fixtures.item()]
        let plan = compile(
            items: items,
            schedules: [
                Fixtures.schedule(itemID: items[0].id, times: [Fixtures.time(8), Fixtures.time(20)]),
                Fixtures.schedule(itemID: items[1].id, times: [Fixtures.time(8)]),
                // The same time in the zone of the device joins the series of the device (D047).
                Fixtures.schedule(itemID: items[2].id, times: [Fixtures.time(8)], timeZonePolicy: .followsDevice),
            ]
        )

        #expect(plan.requests.map(\.identifier) == ["series|device|08:00|daily", "series|Asia/Shanghai|20:00|daily"])
        #expect(plan.series.map(\.members.count) == [3, 1])
        // The trigger is the wall-clock time. A named zone keeps its zone. It has no weekday and no date.
        var evening = DateComponents()
        evening.timeZone = TimeZone(identifier: "Asia/Shanghai")
        evening.hour = 20
        evening.minute = 0
        #expect(plan.requests[1].trigger.dateComponents == evening)
        #expect(plan.requests[0].trigger.dateComponents == DateComponents(hour: 8, minute: 0))
    }

    @Test func weeklyRuleGivesOneRequestForEachWeekdayAndNoDayGetsTwo() throws {
        let items = [Fixtures.item(name: "Iron"), Fixtures.item(name: "Zinc")]
        let someDays = Fixtures.schedule(
            itemID: items[0].id,
            times: [Fixtures.time(9)],
            weeklyRule: try WeeklyRule(weekdays: [.monday, .wednesday, .sunday])
        )
        let requests = compile(items: items, schedules: [someDays]).requests
        #expect(requests.map(\.identifier).map { $0.suffix(2) } == ["|1", "|3", "|7"])

        // 2 March 2026 is a Monday. From that day, each trigger first matches 09:00 on its own weekday.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let next = requests.map { calendar.nextDate(after: monday, matching: $0.trigger.dateComponents, matchingPolicy: .nextTime) }
        #expect(next == [2, 4, 8].map { calendar.date(from: DateComponents(year: 2026, month: 3, day: $0, hour: 9)) })

        // Another item at 09:00 on every day. Monday must not get the weekly request and the daily one.
        let everyDay = Fixtures.schedule(itemID: items[1].id, times: [Fixtures.time(9)])
        let merged = compile(items: items, schedules: [someDays, everyDay], privacy: .hideNames)
        #expect(merged.requests.map(\.identifier) == ["series|Asia/Shanghai|09:00|daily"])
        #expect(merged.requests[0].trigger.weekday == nil)
        // With names, a day names only its own items (D029). So each weekday gets one request with its own text.
        let named = compile(items: items, schedules: [someDays, everyDay])
        #expect(named.requests.map(\.trigger.weekday) == Weekday.allCases.map(Optional.some))
        #expect(named.requests.map { $0.content.names ?? [] }.prefix(3) == [["Iron", "Zinc"], ["Zinc"], ["Iron", "Zinc"]])
    }

    /// A plan of every second day gets one dated request for each of its next seven due dates (D036).
    @Test func everyOtherDayGivesDatedRequestsForItsDueDatesInsideTheBudget() throws {
        let items = [Fixtures.item(name: "Zinc"), Fixtures.item(name: "Iron")]
        let daily = Fixtures.schedule(itemID: items[0].id, times: [Fixtures.time(8)])
        let alternate = Fixtures.schedule(
            itemID: items[1].id, times: [Fixtures.time(8)], dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 3))
        )
        // 08:00 on 2 March in Shanghai, a day with no dose of the second item.
        let plan = compile(items: items, schedules: [alternate])
        let dates = [3, 5, 7, 9, 11, 13, 15].map { String(format: "2026-03-%02d", $0) }
        #expect(plan.requests.map(\.identifier) == dates.map { "series|Asia/Shanghai|08:00|\($0)" })
        #expect(plan.needs[alternate.id] == .requests(Set(plan.requests.map(\.identifier))))
        // Each request stands for one item (D034).
        #expect(plan.requests.map { $0.content.names ?? [] } == Array(repeating: ["Iron"], count: 7))
        #expect(plan.requests.map(\.content.hasTakenAction) == Array(repeating: true, count: 7))
        let first = plan.requests[0]
        #expect(!first.trigger.repeats)
        var morning = DateComponents()
        morning.timeZone = TimeZone(identifier: "Asia/Shanghai")
        (morning.year, morning.month, morning.day, morning.hour, morning.minute) = (2026, 3, 3, 8, 0)
        #expect(first.trigger.dateComponents == morning)
        #expect(first.userInfo[ReminderRequest.dueDateKey] == "2026-03-03")
        #expect(first.fireDate == Fixtures.instant("2026-03-03T00:00:00Z"))

        // After 08:00 on a due date, that date has no request, and the seven requests start at the next due date.
        let later = compile(items: items, schedules: [alternate], at: "2026-03-03T00:00:01Z")
        #expect(later.requests.map { $0.userInfo[ReminderRequest.dueDateKey] } == [5, 7, 9, 11, 13, 15, 17].map { String(format: "2026-03-%02d", $0) })
        // The dated requests of a time fit together or not at all, so no date is left out with no notice.
        // The repeating request gets the budget first, also when its plan is the later one.
        let small = compile(items: items, schedules: [alternate, daily], requestBudget: 7)
        #expect(small.requests.map(\.identifier) == ["series|Asia/Shanghai|08:00|daily"])
        #expect(small.needs[alternate.id] == .blocked(.overLimit))

        // With a daily item at the same time, the dated request of 3 March names both items (D047).
        // A tap on it finds both doses. A tap on the request of the every-other-day item alone finds only its own (spec 8.3).
        let joined = compile(items: items, schedules: [daily, alternate])
        let both = try #require(joined.requests.first { $0.userInfo[ReminderRequest.dueDateKey] == "2026-03-03" })
        #expect(both.content.names == ["Zinc", "Iron"])
        let resolver = ReminderTapResolver(
            now: Fixtures.instant("2026-03-03T00:01:00Z"), deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
        )
        for (request, slots) in [(both, daily.slots + alternate.slots), (first, alternate.slots)] {
            let delivered = DeliveredReminder(
                deliveredAt: Fixtures.instant("2026-03-03T00:00:00Z"), userInfo: request.userInfo, triggerWeekday: nil
            )
            guard case let .resolved(found) = resolver.resolve(delivered, items: items, schedules: [daily, alternate]) else {
                Issue.record("The reminder did not resolve.")
                continue
            }
            #expect(found.map(\.slotID) == slots.map(\.id))
            #expect(found.map(\.plannedDate) == Array(repeating: Fixtures.date(2026, 3, 3), count: slots.count))
        }
    }

    /// D089: with room in the budget, the dated requests reach further than the minimum, and the plan says where they end.
    @Test func datedRequestsReachFurtherWhenTheBudgetHasRoom() throws {
        let item = Fixtures.item(name: "Iron")
        let alternate = Fixtures.schedule(
            itemID: item.id, times: [Fixtures.time(8)], dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 3))
        )
        let plan = compile(items: [item], schedules: [alternate], longerReach: true)
        #expect(plan.requests.count == 28)
        #expect(plan.requests.last?.userInfo[ReminderRequest.dueDateKey] == "2026-04-26")
        #expect(plan.coverageEnds[alternate.id] == Fixtures.instant("2026-04-26T00:00:00Z"))
        // The minimum reach stays the rule when a longer one would drop a series (D036).
        let tight = compile(items: [item], schedules: [alternate], requestBudget: 7, longerReach: true)
        #expect(tight.requests.count == 7)
        // A plan with repeating requests only has no end.
        let daily = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
        #expect(compile(items: [item], schedules: [daily], longerReach: true).coverageEnds.isEmpty)

        // A record before the time takes today's weekday out of the repeat. Its next weeks get dated requests, up to eight.
        let key = OccurrenceKey(slotID: daily.slots[0].id, plannedDate: Fixtures.date(2026, 3, 2))
        let recorded = ReminderPlan(
            items: [item], schedules: [daily], now: Fixtures.instant("2026-03-01T23:00:00Z"), deviceTimeZone: Fixtures.shanghai,
            closed: [key]
        )
        #expect(recorded.requests.filter { !$0.trigger.repeats }.count == 7)
        #expect(recorded.coverageEnds[daily.id] == Fixtures.instant("2026-04-20T00:00:00Z"))
    }

    /// The dated requests of a cycle are for its days with a dose. So no request names the item on a day
    /// of the pause, and the seven requests continue after the pause (D065, T52).
    @Test func cycleGivesDatedRequestsOnlyForItsDaysOn() {
        let item = Fixtures.item(name: "Iron")
        // 3 days on and 4 days off from 1 March. The run is at 08:00 on 2 March in Shanghai.
        let cycle = Fixtures.schedule(
            itemID: item.id, times: [Fixtures.time(8)], dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 1), on: 3, off: 4)
        )
        let plan = compile(items: [item], schedules: [cycle])
        #expect(
            plan.requests.map { $0.userInfo[ReminderRequest.dueDateKey] }
                == [3, 8, 9, 10, 15, 16, 17].map { String(format: "2026-03-%02d", $0) }
        )
        #expect(plan.needs[cycle.id] == .requests(Set(plan.requests.map(\.identifier))))
    }

    /// A record before the time takes today out of the repeating request, and an item that is due on some days
    /// joins the one request of its time (D047). 2 March 2026 is a Monday, and the run is at 08:00.
    @Test func recordBeforeTheTimeAndEveryOtherDayItemKeepOneRequestForEachFireTime() throws {
        let items = [Fixtures.item(name: "Iron"), Fixtures.item(name: "Zinc")]
        let both = items.map { Fixtures.schedule(itemID: $0.id, times: [Fixtures.time(9)]) }
        func closed(_ schedule: Schedule) -> Set<OccurrenceKey> {
            [OccurrenceKey(slotID: schedule.slots[0].id, plannedDate: Fixtures.date(2026, 3, 2))]
        }
        func plan(_ schedules: [Schedule], closed: Set<OccurrenceKey> = [], budget: Int = ReminderPlan.requestBudget) -> ReminderPlan {
            ReminderPlan(
                items: items, schedules: schedules, now: Fixtures.instant("2026-03-02T00:00:00Z"),
                deviceTimeZone: Fixtures.shanghai, closed: closed, requestBudget: budget, longerReach: false
            )
        }

        // No record: the one daily request.
        #expect(plan(both).requests.map(\.identifier) == ["series|Asia/Shanghai|09:00|daily"])

        // Iron is recorded: the other six weekdays repeat. Monday names only Zinc, with the action, and next Monday names both.
        let partial = plan(both, closed: closed(both[0])).requests
        #expect(Array(partial.map(\.identifier).prefix(6)) == (2...7).map { "series|Asia/Shanghai|09:00|\($0)" })
        #expect(partial.dropFirst(6).map { $0.content.names ?? [] } as [[String]] == [["Zinc"], ["Iron", "Zinc"]])
        #expect(partial[6].content.hasTakenAction && partial[6].trigger.date == Fixtures.date(2026, 3, 2))
        #expect(partial[6].userInfo[ReminderRequest.openSlotsKey] == both[1].slots[0].id.rawValue.uuidString)

        // Both are recorded: Monday has no request until next Monday.
        let all = plan(both, closed: closed(both[0]).union(closed(both[1]))).requests
        #expect(all.count == 7 && all[6].trigger.date == Fixtures.date(2026, 3, 9))

        // No room: the request of the plan stays, and no other request goes away.
        #expect(plan(both, closed: closed(both[0]), budget: 6).requests.map(\.identifier) == ["series|Asia/Shanghai|09:00|daily"])

        // A daily item and an every-other-day item at one time: each date has one dated request, and a day names
        // an every-other-day item only when it is due.
        let alternate = Fixtures.schedule(itemID: items[1].id, times: [Fixtures.time(9)], dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 2)))
        let mixed = plan([both[0], alternate]).requests
        #expect(mixed.count == 14)
        #expect(Array(mixed.prefix(3).map { $0.content.names ?? [] }) == [["Iron", "Zinc"], ["Iron"], ["Iron", "Zinc"]])
        #expect(Set(mixed.map(\.trigger.date)).count == 14)
    }

    @Test func requestHoldsTheSeriesAndTheRevisionAndNothingOfAnItem() throws {
        let item = Fixtures.item()
        var schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
        let plan = compile(items: [item], schedules: [schedule])
        let request = try #require(plan.requests.first)

        // The text names the item (D029). The identifier and the `userInfo` hold nothing of it.
        // The request stands for one item, so it has the "Taken" action (D034).
        #expect(request.content == ReminderContent(kind: .due, names: [item.name], hasTakenAction: true))
        let neutral = try #require(compile(items: [item], schedules: [schedule], privacy: .hideNames).requests.first)
        #expect(neutral.content == ReminderContent(kind: .due, names: nil, hasTakenAction: true))
        #expect(neutral.identifier == request.identifier && neutral.userInfo == request.userInfo)
        #expect(
            request.userInfo == [
                ReminderRequest.seriesIDKey: plan.series[0].id,
                ReminderRequest.scheduleRevisionKey: plan.series[0].revision,
            ]
        )
        // No name and no ID of an item, a slot, a version, or an occurrence goes to the system.
        let secrets = [item.name, item.id.rawValue.uuidString, schedule.id.rawValue.uuidString]
            + schedule.slots.map(\.id.rawValue.uuidString) + schedule.versions.map(\.id.rawValue.uuidString)
        for text in [request.identifier] + request.userInfo.values {
            #expect(!secrets.contains { text.localizedCaseInsensitiveContains($0) })
        }

        // The same plan gives the same revision. A new version at the same time gives the same identifier
        // and another revision, so the request is replaced and a tap can tell an older plan.
        #expect(compile(items: [item], schedules: [schedule]).requests == plan.requests)
        try schedule.changeTime(of: schedule.slots[0].id, to: Fixtures.time(8), effectiveFrom: Fixtures.date(2026, 3, 1))
        // On the day before the new version starts, the plan still has the request of the version in force.
        #expect(compile(items: [item], schedules: [schedule], at: "2026-02-28T12:00:00Z").requests == plan.requests)
        let edited = try #require(compile(items: [item], schedules: [schedule]).requests.first)
        #expect(edited.identifier == request.identifier)
        #expect(edited.userInfo[ReminderRequest.scheduleRevisionKey] != request.userInfo[ReminderRequest.scheduleRevisionKey])
    }

    @Test func scheduleThatGetsNoRequestIsReported() {
        let item = Fixtures.item()
        let schedules = [8, 12, 20].map { Fixtures.schedule(itemID: item.id, times: [Fixtures.time($0)]) }
        var ending = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(7)])
        ending.endDate = Fixtures.date(2026, 6, 30)

        // The budget has room for two requests. The schedules that come first keep theirs.
        let plan = compile(items: [item], schedules: [ending] + schedules, requestBudget: 2)

        #expect(plan.requests.map(\.identifier) == ["series|Asia/Shanghai|08:00|daily", "series|Asia/Shanghai|12:00|daily"])
        #expect(plan.needs[schedules[0].id] == .requests(["series|Asia/Shanghai|08:00|daily"]))
        #expect(plan.needs[schedules[2].id] == .blocked(.overLimit))
        // A repeating request never ends, so a schedule with an end date gets none (spec 8.4).
        #expect(plan.needs[ending.id] == .blocked(.endDate))
    }
}
