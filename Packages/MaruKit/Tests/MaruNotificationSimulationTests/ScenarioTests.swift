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

    /// The maintainer's iPhone, 2026-10-16: a record, an undo, and then a time edit gave no alarm at the new time (D095).
    @Test func aTimeEditAfterAnUndoRingsAtTheNewTimeToday() async throws {
        let p = try await phone("2026-10-15 12:00")
        try await p.addItem("Zinc", at: ["12:20"], alarm: true)
        await p.advance(to: "2026-10-15 12:25")
        try await p.record("Zinc")
        try await p.changeTime("Zinc", to: "12:30")
        await p.advance(to: "2026-10-15 12:31")
        try await p.record("Zinc")
        try await p.undo("Zinc")
        try await p.changeTime("Zinc", to: "12:35")
        await p.expectCorrect("undo, then a time edit")
        let before = await p.alarmCenter.rang.count
        await p.advance(to: "2026-10-15 12:36")
        p.expectCorrectDeliveries()
        #expect(await p.alarmCenter.rang.count == before + 1, "no alarm at the new time of an open dose")
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
        try await p.perform(.taken, on: id)
        await p.expectCorrect("after the action")
        #expect(await p.center.shown.isEmpty)
    }

    @Test func theTakenActionOfAFirstReminder() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        let id = try #require(await p.center.shown.keys.first)
        try await p.perform(.taken, on: id)
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

    @Test func aLateAlarmScheduleIsCancelledWhenTheDoseHasARecord() async throws {
        let p = try await phone()
        p.checks.alarmsFail = true
        // AlarmKit holds the schedule call, so the call times out, and the item keeps its banner.
        await p.alarmCenter.setScheduleHangs(true)
        p.checks.alarms = false
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.record("Zinc")
        // AlarmKit answers late. The alarm that it registers now is for a dose with a record.
        await p.alarmCenter.setScheduleHangs(false)
        try await Task.sleep(for: .milliseconds(600))
        // The late schedule checks the newest plan by itself, before any new run.
        #expect(!(await p.alarmCenter.alarms.values.contains { $0.fireDate == p.instant("2026-10-15 09:00") }))
        p.checks.alarmsFail = false
        p.checks.alarms = true
        await p.foreground()
        await p.expectCorrect("the late alarm is gone")
    }

    /// N9 (D089): the alarm call times out, so the item keeps its banner. When AlarmKit answers late, the alarm that it
    /// registers must go, or the alarm rings beside its fallback banner.
    @Test func aLateAlarmThatTheRunGaveUpOnIsCancelledBesideItsBanner() async throws {
        let p = try await phone()
        p.checks.alarmsFail = true
        await p.alarmCenter.setScheduleHangs(true)
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        await p.expectCorrect("the banner stands in for the alarm that timed out")
        await p.alarmCenter.setScheduleHangs(false)
        try await Task.sleep(for: .milliseconds(600))
        #expect(await p.alarmCenter.alarms.isEmpty, "the late alarm rings beside the banner")
        await p.expectCorrect("banner only")
    }

    /// N5 (D089): with the alarm on at the first save, the series run has no request, so it never asked for the notification
    /// permission. Then no banner stands in for a failed alarm, and no follow-up ever comes.
    @Test func anAlarmItemAtTheFirstSaveAsksForTheNotificationPermission() async throws {
        let p = try await phone()
        await p.setNotifications(.notDetermined)
        p.checks.followUpCoverage = true
        try await p.addItem("Zinc", at: ["09:00"], followUp: again, alarm: true)
        #expect(p.device.authorization == .authorized, "the prompt was never shown")
        #expect(await p.center.pending.keys.contains { $0.hasPrefix("followup|") }, "no follow-up is set")
        await p.expectCorrect("alarm, then follow-ups")
    }

    // MARK: A delivered reminder and a later record (maintainer requirement of D086)

    @Test func recordedAtOneAfterAReminderOfNoonLeavesNotificationCenter() async throws {
        let p = try await phone("2026-10-15 11:00")
        try await p.addItem("Zinc", at: ["12:00"])
        await p.advance(to: "2026-10-15 12:01")
        #expect(await p.center.shown.count == 1)
        await p.advance(to: "2026-10-15 13:00")
        try await p.record("Zinc")
        #expect(await p.center.shown.isEmpty)
        await p.expectCorrect("recorded at 13:00")
    }

    @Test func oneOfTwoItemsRecordedRemovesTheOldNotificationAndPostsNoNewBanner() async throws {
        let p = try await phone("2026-10-15 11:00")
        try await p.addItem("Zinc", at: ["12:00"])
        try await p.addItem("Iron", at: ["12:00"])
        await p.advance(to: "2026-10-15 12:01")
        let deliveries = await p.center.deliveries.count
        await p.advance(to: "2026-10-15 13:00")
        try await p.record("Zinc")
        #expect(await p.center.shown.isEmpty, "the old notification names a closed dose")
        #expect(await p.center.deliveries.count == deliveries, "no new banner for Iron")
        await p.expectCorrect("Zinc recorded, Iron still open on Today")
    }

    @Test func recordedFromTheTakenActionLeavesNotificationCenter() async throws {
        let p = try await phone("2026-10-15 11:00")
        try await p.addItem("Zinc", at: ["12:00"])
        await p.advance(to: "2026-10-15 12:01")
        try await p.perform(.taken, on: try #require(await p.center.shown.keys.first))
        #expect(await p.center.shown.isEmpty)
        await p.expectCorrect("Taken action")
    }

    @Test func recordedFromTheWidgetLeavesNotificationCenter() async throws {
        let p = try await phone("2026-10-15 11:00")
        try await p.addItem("Zinc", at: ["12:00"])
        await p.advance(to: "2026-10-15 12:01")
        p.terminate()
        await p.advance(to: "2026-10-15 13:00")
        try await p.recordFromWidget("Zinc")
        #expect(await p.center.shown.isEmpty)
        await p.expectCorrect("widget")
    }

    @Test func recordedTheNextMorningForYesterdayLeavesNotificationCenter() async throws {
        let p = try await phone("2026-10-15 11:00")
        try await p.addItem("Zinc", at: ["12:00"])
        await p.advance(to: "2026-10-15 12:01")
        await p.advance(to: "2026-10-16 08:00")
        try await p.record("Zinc", date: p.date("2026-10-15"))
        #expect(await !p.center.shown.keys.contains { $0.contains("2026-10-15") })
        await p.expectCorrect("next morning")
    }

    // MARK: The system is slow or loses calls

    @Test func aSlowRemovalThatTheAppSendsAgainNeverDeletesTheNewRequest() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["12:00"])
        try await p.addItem("Iron", at: ["12:00"])
        // The system does a removal after 25 reads. A record removes the daily request, and an undo wants it again.
        await p.center.setRemovalLatency(25)
        // While the system is slow, a run ends with removals open, and an old request can still be pending.
        p.autoCheck = false
        try await p.record("Zinc")
        try await p.undo("Zinc")
        try await p.record("Zinc")
        try await p.undo("Zinc")
        for _ in 0..<40 { _ = await p.center.pendingRequests() }
        p.autoCheck = true
        await p.foreground()
        await p.expectCorrect("slow removals have completed")
    }

    @Test func aRemovalThatTheSystemNeverDoesIsAskedAgainByEveryRun() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["12:00"])
        try await p.addItem("Iron", at: ["12:00"])
        await p.center.setDropsRemovals(true)
        p.autoCheck = false
        try await p.record("Zinc")
        await p.center.setDropsRemovals(false)
        p.autoCheck = true
        await p.foreground()
        await p.expectCorrect("the next run removed it")
    }

    // MARK: Generations (D086)

    @Test func aRollbackOfTheClockAndARestartNeverRepeatNorReorderAGeneration() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["12:00"])
        try await p.addItem("Iron", at: ["12:00"])
        let before = p.counter.current
        // The iPhone restarts and its clock goes back by two days.
        p.restart()
        p.device.now = p.instant("2026-10-13 09:00")
        await p.foreground()
        try await p.record("Zinc")
        try await p.undo("Zinc")
        try await p.record("Iron")
        #expect(p.counter.current > before)
        let ids = await p.center.pending.keys
        #expect(Set(ids).count == ids.count)
        await p.expectCorrect("after the rollback")
    }

    @Test func aStopBetweenAnAddAndTheRemovalLeavesTwoGenerationsUntilTheNextRun() async throws {
        for newer in [true, false] {
            let p = try await phone("2026-10-15 08:00")
            try await p.addItem("Zinc", at: ["12:00"])
            let id = try #require(await p.center.pending.keys.first { $0.hasPrefix("series|device|12:00|daily") })
            let held = try #require(await p.center.pending[id])
            // A second generation of the base: with a higher counter and old text (newer), or with a lower counter (older).
            let second = SimNotification(
                identifier: id.replacingOccurrences(of: #"g\d{12}"#, with: newer ? "g999999999999" : "g000000000001", options: .regularExpression),
                text: newer ? ReminderText(title: "Time to take", body: "Iron") : held.text, userInfo: held.userInfo,
                presentation: held.presentation, threadIdentifier: nil, trigger: held.trigger
            )
            await p.center.inject(second)
            p.terminate()
            await p.foreground()
            await p.expectCorrect("the next run keeps one generation (newer \(newer))")
        }
    }

    @Test func atTheLimitAReplacementRemovesItsOlderGenerationFirstAndDropsNothing() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["10:00"])
        try await p.addItem("Iron", at: ["11:00"])
        try await p.addItem("Copper", at: ["12:00"])
        // Other requests of the app fill the system to the limit of 64.
        let filler = 64 - (await p.center.pending.count)
        for number in 0..<filler {
            await p.center.inject(SimNotification(
                identifier: "other|\(number)", text: ReminderText(title: "x", body: "y"), userInfo: [:], presentation: nil,
                threadIdentifier: nil, trigger: .instant(p.instant("2026-12-01 09:00").addingTimeInterval(Double(number)))
            ))
        }
        #expect(await p.center.pending.count == 64)
        // Three replacements.
        try await p.rename("Zinc", to: "Zinc Citrate")
        try await p.rename("Iron", to: "Iron Bisglycinate")
        try await p.rename("Copper", to: "Copper Gluconate")
        #expect(await p.center.pending.count <= 64)
        await p.expectCorrect("three replacements at the limit")
    }

    @Test func requestsOfBuild6AreMovedToGenerationsAndAnOldRemovalChangesNothing() async throws {
        let p = try await phone("2026-10-15 08:00")
        try await p.addItem("Zinc", at: ["09:00", "12:00"], followUp: again)
        try await p.addItem("Iron", at: ["12:00"], followUp: again)
        await p.advance(to: "2026-10-15 09:05")
        let legacy = await p.center.pending.keys.sorted().filter { $0.hasPrefix("series|") || $0.hasPrefix("followup|") }
        // Build 6 sent a removal of two of its requests, and the system did not do it yet.
        await p.downgradeToBuild6(pendingRemovals: Array(legacy.prefix(2)).map {
            $0.replacingOccurrences(of: #"\|g\d{12}r[0-9a-f]{4}$"#, with: "", options: .regularExpression)
        })
        #expect(await p.center.pending.keys.allSatisfy { !$0.contains("|g") })
        await p.foreground()
        await p.expectCorrect("first run of the new build")
        let ids = await p.center.pending.keys
        #expect(ids.allSatisfy { $0.contains("|g") }, "no request of build 6 is left")
        #expect(p.seriesMigration.isDone && p.followUpMigration.isDone)
        for _ in 0..<10 { _ = await p.center.pendingRequests() }
        await p.expectCorrect("after the old removals took effect")
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
