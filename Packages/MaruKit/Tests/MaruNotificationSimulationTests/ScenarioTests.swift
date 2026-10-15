import Foundation
import Testing
@testable import MaruCore

/// Edge cases of D086. Each test drives user actions and clock moves, and the oracle checks the invariant after each step.
@Suite("Notification scenarios")
struct ScenarioTests {
    private func phone(_ start: String = "2026-10-15 07:00") async throws -> Phone {
        try await Phone.make(start: start)
    }

    private let again = FollowUpSetting(count: .three, interval: .minutes15)

    // MARK: Records

    @Test func recordSkipAndUndoBeforeAndAfterTheTime() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.expectCorrect("setup")
        try await p.record("Zinc")
        await p.expectCorrect("record before")
        try await p.undo("Zinc")
        await p.expectCorrect("undo before")
        try await p.record("Zinc", .skipped)
        try await p.record("Iron")
        await p.expectCorrect("both closed: no request for 09:00 today")
        await p.advance(to: "2026-10-15 09:05")
        p.expectCorrectDeliveries()
        #expect(await p.center.shown.isEmpty)
        try await p.undo("Iron")
        await p.expectCorrect("undo after the time")
        try await p.record("Iron")
        await p.advance(to: "2026-10-16 09:05")
        p.expectCorrectDeliveries()
        await p.foreground()
        await p.expectCorrect("next day")
    }

    @Test func recordAfterTheTimeRemovesTheDeliveredReminder() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        #expect(await p.center.shown.count == 1)
        try await p.record("Zinc")
        await p.expectCorrect("one of two recorded: the old text is gone")
        try await p.record("Iron")
        await p.expectCorrect("both recorded")
        #expect(await p.center.shown.isEmpty)
    }

    @Test func recordOfTomorrowAndOfYesterday() async throws {
        let p = try await phone("2026-10-15 23:00")
        try await p.addItem("Zinc", at: ["23:30", "08:00"])
        await p.advance(to: "2026-10-15 23:31")
        await p.advance(to: "2026-10-16 00:30")
        try await p.record("Zinc", slot: 0, date: p.date("2026-10-15"))
        await p.expectCorrect("a late record of yesterday")
        try await p.record("Zinc", slot: 1, date: p.date("2026-10-17"))
        await p.expectCorrect("an early record of the day after tomorrow is outside the window, so no check of it")
    }

    // MARK: Edits

    @Test func renameTimeEditAddTimeArchiveRestoreDeleteAndPause() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: again)
        try await p.addItem("Iron", at: ["09:00", "21:00"])
        try await p.rename("Zinc", to: "Zinc Citrate")
        await p.expectCorrect("rename")
        try await p.changeTime("Iron", slot: 0, to: "10:15")
        await p.expectCorrect("time edit")
        try await p.addTime("Iron", "15:00")
        await p.expectCorrect("add time")
        try await p.archive("Iron")
        await p.expectCorrect("archive")
        try await p.restore("Iron")
        await p.expectCorrect("restore")
        try await p.pause("Iron")
        await p.expectCorrect("pause")
        await p.advance(to: "2026-10-15 09:05")
        try await p.resume("Iron")
        await p.expectCorrect("resume")
        try await p.delete("Zinc Citrate")
        await p.expectCorrect("delete")
        p.expectCorrectDeliveries()
    }

    @Test func archiveWithADeliveredReminderAndDeliveredFollowUps() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: again)
        try await p.addItem("Iron", at: ["09:00"], followUp: again)
        await p.advance(to: "2026-10-15 09:20")
        #expect(await p.center.shown.count >= 2)
        try await p.archive("Iron")
        await p.expectCorrect("archive Iron")
        for text in await p.center.shown.values.map(\.notification.text.body) { #expect(!text.contains("Iron")) }
    }

    // MARK: Plans

    @Test func weekdaysCyclesAndFixedZonesShareATime() async throws {
        let p = try await phone()
        try await p.addItem("Daily", at: ["09:00"])
        try await p.addItem("Mondays", at: ["09:00"], days: .weekdays([.monday, .thursday]))
        try await p.addItem("Every Other Day", at: ["09:00"], days: .cycle(on: 1, off: 1, start: p.date("2026-10-15")))
        try await p.addItem("Shanghai", at: ["07:00"], zone: .fixed(NamedTimeZone(identifier: "Asia/Shanghai")))
        p.checks.coverageHours = 24 * 8
        await p.expectCorrect("setup")
        try await p.record("Daily")
        await p.expectCorrect("record one of the shared time")
        await p.advance(to: "2026-10-15 09:05")
        p.expectCorrectDeliveries()
        await p.advance(to: "2026-10-16 09:05")
        p.expectCorrectDeliveries()
        await p.foreground()
        await p.expectCorrect("next day")
    }

    // MARK: Follow-ups

    @Test func followUpsStopAtARecordAndComeBackAtAnUndo() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: FollowUpSetting(count: .untilRecorded, interval: .minutes5))
        try await p.addItem("Iron", at: ["09:00"], followUp: again)
        p.checks.followUpCoverage = true
        await p.expectCorrect("setup")
        await p.advance(to: "2026-10-15 09:17")
        p.expectCorrectDeliveries()
        try await p.record("Zinc")
        await p.expectCorrect("Zinc recorded")
        try await p.record("Iron")
        await p.expectCorrect("both recorded: no follow-up left")
        try await p.undo("Iron")
        await p.expectCorrect("undo")
    }

    @Test func changeRemindAgainPerItemAndForAllItems() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00", "21:00"], followUp: again)
        p.checks.followUpCoverage = true
        try await p.setFollowUp("Zinc", FollowUpSetting(count: .two, interval: .minutes30))
        await p.expectCorrect("per item")
        try await p.setAllFollowUp(FollowUpSetting(count: .five, interval: .minutes10))
        await p.expectCorrect("all items")
        try await p.setAllFollowUp(nil)
        await p.expectCorrect("off for all")
    }

    @Test func theTakenActionOfAFollowUpRecordsAndClearsTheNotification() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: again)
        await p.advance(to: "2026-10-15 09:16")
        let id = try #require(await p.center.shown.keys.first { $0.hasPrefix("followup|") })
        try await p.takenFromNotification(id)
        await p.expectCorrect("after the action")
        #expect(await p.center.shown.isEmpty)
    }

    @Test func theTakenActionOfAFirstReminder() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        let id = try #require(await p.center.shown.keys.first)
        try await p.takenFromNotification(id)
        await p.expectCorrect("after the action")
    }

    // MARK: Alarms

    @Test func alarmOnAndOffAndRecord() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.addItem("Iron", at: ["09:00"])
        await p.expectCorrect("alarm item next to a notification item")
        try await p.setAlarm("Zinc", false)
        await p.expectCorrect("alarm off")
        try await p.setAlarm("Zinc", true)
        try await p.record("Zinc")
        await p.expectCorrect("record cancels the alarm")
        try await p.setAllAlarm(false)
        await p.expectCorrect("all alarms off")
    }

    @Test func aRefusedAlarmKeepsTheNotification() async throws {
        let p = try await phone()
        p.setAlarmsAllowed(false)
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.expectCorrect("permission refused: notification stays")
        p.setAlarmsAllowed(true)
        await p.alarmCenter.setSchedulingFails(true)
        p.checks.alarmsFail = true
        await p.foreground()
        await p.expectCorrect("the system refuses the alarm: notification stays")
    }

    @Test func aHangingAlarmSystemDoesNotBlockTheRunsOrTheBanners() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.addItem("Iron", at: ["09:00"])
        await p.expectCorrect("alarm item next to a notification item")
        // AlarmKit stops answering. Every run must end, and the item with the alarm gets its notification (D079, D086).
        await p.alarmCenter.setHangs(true)
        p.checks.alarmsFail = true
        // The waiting alarms cannot be cancelled while it hangs, so an alarm and a banner can coexist (D079). Only the banner is checked.
        p.checks.alarms = false
        try await p.record("Iron")
        try await p.undo("Iron")
        try await p.rename("Zinc", to: "Zinc Citrate")
        await p.expectCorrect("runs end while the alarm system hangs")
        await p.alarmCenter.setHangs(false)
        p.checks.alarmsFail = false
        p.checks.alarms = true
        await p.foreground()
        await p.expectCorrect("the alarm system answers again")
    }

    // MARK: Settings and the world

    @Test func hiddenNamesAndShownNames() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.setPrivacy(.hideNames)
        await p.expectCorrect("hidden")
        try await p.record("Zinc")
        await p.expectCorrect("hidden and one recorded")
        await p.setPrivacy(.showNames)
        await p.expectCorrect("shown")
    }

    @Test func permissionOffThenOn() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.setNotifications(.denied)
        try await p.archive("Iron")
        #expect(await p.center.pending.values.allSatisfy { !$0.text.body.contains("Iron") })
        await p.setNotifications(.authorized)
        await p.foreground()
        await p.expectCorrect("permission back")
    }

    @Test func timeZoneChangeWithTheAppClosed() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00", "21:00"], followUp: again)
        try await p.addItem("Iron", at: ["09:00"], zone: .fixed(NamedTimeZone(identifier: "Asia/Shanghai")))
        try p.changeZone(to: "America/Los_Angeles")
        await p.advance(to: "2026-10-15 22:00")
        await p.foreground()
        await p.expectCorrect("after the run in the new zone")
    }

    @Test func midnightAndAnAppThatDoesNotOpenForDays() async throws {
        let p = try await phone("2026-10-15 20:00")
        try await p.addItem("Zinc", at: ["21:00"], followUp: again)
        try await p.addItem("Iron", at: ["21:00"], days: .cycle(on: 1, off: 2, start: p.date("2026-10-15")))
        await p.advance(to: "2026-10-15 21:20")
        p.terminate()
        await p.advance(to: "2026-10-18 10:00")
        await p.foreground()
        await p.expectCorrect("three days later: old delivered notifications are gone")
    }

    @Test func restartOfTheIPhoneKeepsThePendingRequests() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        p.restart()
        await p.advance(to: "2026-10-15 09:01")
        p.expectCorrectDeliveries()
        await p.foreground()
        await p.expectCorrect("after the restart")
    }

    // MARK: The system

    @Test func slowRemovalAndDroppedAdds() async throws {
        let p = try await phone()
        await p.center.setRemovalLatency(3)
        try await p.addItem("Zinc", at: ["09:00", "21:00"], followUp: again)
        try await p.addItem("Iron", at: ["21:00"])
        try await p.record("Iron")
        await p.expectCorrect("slow removal")
        await p.center.setDropsNextAdds(2)
        try await p.archive("Zinc")
        await p.expectCorrect("two adds dropped")
    }

    @Test func manyItemsStayInsideTheSystemLimit() async throws {
        let p = try await phone()
        for number in 0..<18 {
            try await p.addItem("Item \(number)", at: [String(format: "%02d:00", 8 + number % 12), String(format: "%02d:30", 8 + number % 12)], followUp: again)
        }
        p.checks.coverage = false
        let count = await p.center.pending.count
        #expect(count <= 64)
        // The series requests come first (spec 8.4): every first reminder of the next day is there.
        p.checks.coverage = true
        p.checks.coverageHours = 20
        await p.expectCorrect("many items")
    }

    @Test func aUserActionDuringARunIsCorrectedByTheNextRun() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        // The user records Iron while the run after the archive of Zinc is in progress.
        let store = p.store
        _ = store
        p.nextRunInterleave = [4: { [p] in try? await p.recordWithoutRun("Iron") }]
        try await p.archive("Zinc")
        await p.foreground()
        await p.expectCorrect("race")
    }
}
