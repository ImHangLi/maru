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
        requestBudget: Int = ReminderPlan.requestBudget
    ) -> ReminderPlan {
        ReminderPlan(
            items: items,
            schedules: schedules,
            now: Fixtures.instant(now),
            deviceTimeZone: Fixtures.shanghai,
            privacy: privacy,
            requestBudget: requestBudget
        )
    }

    @Test func slotsAtTheSameTimeShareOneRequest() {
        let items = [Fixtures.item(), Fixtures.item(), Fixtures.item()]
        let plan = compile(
            items: items,
            schedules: [
                Fixtures.schedule(itemID: items[0].id, times: [Fixtures.time(8), Fixtures.time(20)]),
                Fixtures.schedule(itemID: items[1].id, times: [Fixtures.time(8)]),
                // The same time in the zone of the device is another series. It moves when the device moves.
                Fixtures.schedule(itemID: items[2].id, times: [Fixtures.time(8)], timeZonePolicy: .followsDevice),
            ]
        )

        #expect(
            plan.requests.map(\.identifier)
                == ["series|Asia/Shanghai|08:00|daily", "series|Asia/Shanghai|20:00|daily", "series|device|08:00|daily"]
        )
        #expect(plan.series.map(\.members.count) == [2, 1, 1])
        // The trigger is the wall-clock time in the named zone. It has no weekday and no date.
        var morning = DateComponents()
        morning.timeZone = TimeZone(identifier: "Asia/Shanghai")
        morning.hour = 8
        morning.minute = 0
        #expect(plan.requests[0].trigger.dateComponents == morning)
        #expect(plan.requests[2].trigger.dateComponents == DateComponents(hour: 8, minute: 0))
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
