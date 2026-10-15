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

    /// D089: a repeating alarm that rings now is not waiting. The run must not register a second one, or both repeat after "Stop".
    @Test func aRingingRepeatingAlarmIsNotRegisteredAgain() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.alarmCenter.startRinging()
        p.checks.alarms = false
        await p.foreground()
        let waiting = await p.alarmCenter.alarms.count
        #expect(waiting == 0, "a second repeating alarm was registered while the first rings")
    }

    /// D089: an edit while the repeating alarm rings gives a new alarm. The ringing one is not stopped, its id waits in the
    /// durable set, and it is cancelled at the first run after "Stop". Both must not repeat.
    @Test func anObsoleteRingingAlarmIsCancelledAfterStop() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.alarmCenter.startRinging()
        p.checks.alarms = false
        try await p.rename("Zinc", to: "Zinc B")
        let ringing = await p.alarmCenter.ringing
        #expect(ringing.count == 1, "a run stopped the ringing alarm")
        #expect(p.alarmIndex.quiet() == ringing, "the ringing alarm is not in the set that waits for quiet")
        await p.alarmCenter.stopRinging()
        await p.foreground()
        let waiting = await p.alarmCenter.alarms.values.map(\.names)
        #expect(waiting == [["Zinc B"]], "the old alarm still repeats: \(waiting)")
        #expect(p.alarmIndex.quiet().isEmpty)
    }

    /// D089: rename A, B, A while the alarm of A rings. After "Stop" the alarm of A is wanted again. It must not be cancelled
    /// with no replacement.
    @Test func aWantedAlarmInTheQuietSetIsNotCancelled() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.alarmCenter.startRinging()
        p.checks.alarms = false
        try await p.rename("Zinc", to: "Zinc B")
        try await p.rename("Zinc B", to: "Zinc")
        await p.alarmCenter.stopRinging()
        await p.foreground()
        let waiting = await p.alarmCenter.alarms.values.map(\.names)
        #expect(waiting == [["Zinc"]], "the dose has no alarm or two: \(waiting)")
        #expect(p.alarmIndex.quiet().isEmpty)
    }

    /// D089: alarms from a build with no index, and one unreadable schedule. The first run cancels every alarm with no entry and
    /// schedules the alarms of the plan again with entries.
    @Test func theFirstRunMakesTheAlarmIndexComplete() async throws {
        let p = try await phone()
        p.autoCheck = false
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.addItem("Iron", at: ["21:00"], alarm: true)
        p.alarmIndex.reset()
        try await p.corruptSchedule("Iron")
        await p.foreground()
        let alarms = await p.alarmCenter.alarms
        #expect(alarms.values.map(\.names) == [["Zinc"]], "legacy alarms are left: \(alarms.values.map(\.names))")
        #expect(alarms.keys.allSatisfy { p.alarmIndex.schedules(of: $0) != nil }, "an alarm has no index entry")
        #expect(p.alarmIndex.isComplete)
    }
}
