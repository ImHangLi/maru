import Foundation
import Testing
@testable import MaruCore

/// D089: how long the reminders and the alarms last when the app does not run. A repeating request or alarm never runs out.
/// A dated request lasts as far as the budget allows, and each run sets the dates again.
@Suite("Coverage when the app does not run")
struct CoverageTests {
    private func phone(_ start: String = "2026-10-15 07:00") async throws -> Phone {
        try await Phone.make(start: start)
    }

    /// N2 (D089): an alarm item has no banner. Its alarms were planned for 7 days, so 7 days without the app ended the reminder.
    @Test func aDailyAlarmDoesNotRunOut() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.advance(to: "2026-11-25 09:30")
        let rang = await p.alarmCenter.rang.count
        #expect(rang >= 41, "the alarm stopped after \(rang) days")
    }

    @Test func aWeeklyAlarmDoesNotRunOut() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], days: .weekdays([.monday, .thursday]), alarm: true)
        await p.advance(to: "2026-12-10 09:30")
        // 8 weeks, two days in each.
        let rang = await p.alarmCenter.rang.count
        #expect(rang >= 16)
    }

    /// N4 for an alarm (D089): the alarm of the recorded day leaves its repeat. The next weeks of that weekday keep their alarm.
    @Test func aRecordBeforeTheAlarmKeepsTheAlarmsOfTheLaterWeeks() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.record("Zinc")
        await p.advance(to: "2026-11-04 09:30")
        // Each day from 16 October to 4 November. The recorded day has none.
        let rang = await p.alarmCenter.rang.count
        #expect(rang == 20)
    }

    /// N4 (D089): a record before the dose time takes that weekday out of the repeating request. The next weeks of that
    /// weekday got no request after the second one, so they had no reminder until the app ran.
    @Test func aRecordBeforeTheTimeKeepsTheRemindersOfTheLaterWeeks() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.record("Zinc")
        let before = await p.center.deliveries.count
        await p.advance(to: "2026-11-12 09:30")
        // Each day from 16 October to 12 November: 28 days.
        let after = await p.center.deliveries.count
        #expect(after - before == 28)
        p.expectCorrectDeliveries()
    }

    /// The dated requests of a plan with a day cycle reach further than 7 due dates when the budget has room (D089).
    @Test func aDayCyclePlanRemindsOnMoreThanSevenDueDatesWithoutTheApp() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], days: .cycle(on: 1, off: 1, start: p.date("2026-10-15")))
        let end = try #require(p.lastOutcome?.reminders.coverageEnds.values.first)
        #expect(end > p.instant("2026-11-20 00:00"), "the plan says that its reminders stop early")
        await p.advance(to: "2026-11-08 09:30")
        // Every other day from 15 October to 8 November.
        let delivered = await p.center.deliveries.count
        #expect(delivered == 13)
        p.expectCorrectDeliveries()
    }
}
