import Foundation
import Testing
@testable import MaruCore
@testable import MaruNotifications

/// The actions of a reminder (D090): "Take All", "Skip", and "Remind in 10 min". Each scenario drives the real action use case on
/// the real database through `Phone.perform`, and the oracle checks the category and the level of every pending request,
/// and the snoozes of the user, after each step.
@Suite("Notification actions")
struct ActionTests {
    private func phone(_ start: String = "2026-10-15 07:00") async throws -> Phone {
        try await Phone.make(start: start)
    }

    /// The identifier of the one delivered notification whose identifier starts with `prefix`.
    private func shown(_ p: Phone, _ prefix: String) async throws -> String {
        try #require(await p.center.shown.keys.first { $0.hasPrefix(prefix) }, "no delivered notification \(prefix)")
    }

    private func category(_ p: Phone, _ identifier: String) async throws -> ReminderCategory? {
        await p.center.shown[identifier]?.notification.presentation?.category
    }

    private func pendingIdentifiers(_ p: Phone, containing text: String) async -> [String] {
        await p.center.pending.keys.filter { $0.contains(text) }.sorted()
    }

    // MARK: Take All

    @Test func takeAllRecordsEveryNamedDoseAndClearsTheNotification() async throws {
        let p = try await phone()
        for name in ["Zinc", "Iron", "Copper"] { try await p.addItem(name, at: ["09:00"]) }
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        #expect(try await category(p, id) == .group)

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.named == 3 && result.recorded.count == 3 && result.notRecordedCount == 0)
        #expect(result.recorded.allSatisfy { $0.event.action == .taken && $0.event.source == .notificationAction })
        #expect(await p.center.shown.isEmpty)
        await p.expectCorrect("after Take All")
    }

    /// Another path recorded one dose before the app cleaned the notification (a race that the user rarely meets).
    @Test func takeAllWithOneDoseAlreadyRecordedLeavesThatDoseAsItIs() async throws {
        let p = try await phone()
        for name in ["Zinc", "Iron", "Copper"] { try await p.addItem(name, at: ["09:00"]) }
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        try await p.recordWithoutRun("Zinc")

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.recorded.count == 2 && result.unchangedCount == 1 && result.notRecordedCount == 0)
        #expect(try await p.status(of: "Zinc") == .taken)
        await p.expectCorrect("after Take All with one dose closed")
    }

    @Test func takeAllNeverReplacesASkip() async throws {
        let p = try await phone()
        for name in ["Zinc", "Iron"] { try await p.addItem(name, at: ["09:00"]) }
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        try await p.recordWithoutRun("Zinc", .skipped)

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.recorded.count == 1 && result.unchangedCount == 1)
        #expect(try await p.status(of: "Zinc") == .skipped)
        #expect(try await p.status(of: "Iron") == .taken)
        await p.expectCorrect("a skip stays")
    }

    @Test func aRecordBeforeTheTimeLeavesTheGroupActionWithTheOtherDoses() async throws {
        let p = try await phone()
        for name in ["Zinc", "Iron", "Copper"] { try await p.addItem(name, at: ["09:00"]) }
        try await p.record("Zinc")
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        #expect(await p.center.shown[id]?.notification.text.body == "Iron and Copper")
        #expect(try await category(p, id) == .group)

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.recorded.count == 2 && result.named == 2)
        await p.expectCorrect("Iron and Copper recorded")
    }

    /// Take All on a follow-up that names a group: each dose has its own schedule version (D089, D090).
    @Test func takeAllAfterAPlanEditRecordsOnlyTheDosesThatStillMatch() async throws {
        let p = try await phone()
        let setting = FollowUpSetting(count: .one, interval: .minutes15)
        try await p.addItem("Zinc", at: ["09:00"], followUp: setting)
        try await p.addItem("Iron", at: ["09:00"], followUp: setting)
        await p.advance(to: "2026-10-15 09:16")
        let id = try await shown(p, "followup|")
        #expect(try await category(p, id) == .group)
        // The text of the notification stays true: the same names. The dose of Zinc has a new schedule version.
        try await p.changeDose("Zinc", to: "2 capsules")
        #expect(await p.center.shown[id] != nil)

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.named == 2 && result.recorded.count == 1 && result.notRecordedCount == 1)
        #expect(try await p.status(of: "Zinc") == .unrecorded)
        #expect(try await p.status(of: "Iron") == .taken)
        await p.expectCorrect("Zinc stays open, and its reminders follow the new plan")
    }

    /// A first reminder has a revision of the whole group. A plan edit that keeps the names makes it older, and the action records nothing.
    @Test func takeAllOnAFirstReminderOfAnOlderPlanRecordsNothing() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        try await p.changeDose("Zinc", to: "2 capsules")
        #expect(await p.center.shown[id] != nil)

        let result = try #require(try await p.perform(.taken, on: id))

        #expect(result.recorded.isEmpty)
        #expect(try await p.status(of: "Zinc") == .unrecorded)
        #expect(try await p.status(of: "Iron") == .unrecorded)
        await p.expectCorrect("nothing recorded")
    }

    /// With group actions the body names every item, so the user sees each dose that "Take All" records (D090).
    @Test func aGroupOfFiveNamesEveryItemAndHasTakeAll() async throws {
        let p = try await phone()
        let names = ["Zinc", "Iron", "Copper", "Iodine", "Selenium"]
        for name in names { try await p.addItem(name, at: ["09:00"]) }
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        let body = try #require(await p.center.shown[id]?.notification.text.body)
        #expect(names.allSatisfy { body.contains($0) } && !body.contains("more"), "\(body)")
        #expect(try await category(p, id) == .group)
        let result = try #require(try await p.perform(.taken, on: id))
        #expect(result.recorded.count == 5)
        await p.expectCorrect("after Take All on five")
    }

    // MARK: Skip

    @Test func skipOnOneItemRecordsASkipAndStopsTheFollowUps() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: FollowUpSetting(count: .three, interval: .minutes10))
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        #expect(try await category(p, id) == .single)

        let result = try #require(try await p.perform(.skip, on: id))

        #expect(result.recorded.count == 1 && result.recorded[0].event.action == .skipped)
        #expect(try await p.status(of: "Zinc") == .skipped)
        #expect(await pendingIdentifiers(p, containing: "|2026-10-15|09:00|+").isEmpty)
        await p.expectCorrect("after Skip")
    }

    @Test func skipAllSkipsTheOpenDosesAndKeepsATakenDose() async throws {
        let p = try await phone()
        for name in ["Zinc", "Iron", "Copper"] { try await p.addItem(name, at: ["09:00"]) }
        await p.advance(to: "2026-10-15 09:01")
        let id = try await shown(p, "series|")
        try await p.recordWithoutRun("Zinc")

        let result = try #require(try await p.perform(.skip, on: id))

        #expect(result.recorded.count == 2 && result.unchangedCount == 1)
        #expect(try await p.status(of: "Zinc") == .taken)
        #expect(try await p.status(of: "Iron") == .skipped)
        #expect(try await p.status(of: "Copper") == .skipped)
        await p.expectCorrect("after Skip All")
    }

    // MARK: Remind in 10 minutes

    @Test func aSnoozeComesBackAfterTenMinutesAndItsActionRecords() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        let first = try await shown(p, "series|")

        #expect(try await p.perform(.snooze, on: first) == nil)

        #expect(await p.center.shown.isEmpty)
        #expect(await pendingIdentifiers(p, containing: "|snooze").count == 1)
        await p.expectCorrect("the snooze request")
        await p.advance(to: "2026-10-15 09:12")
        p.expectCorrectDeliveries()
        let snooze = try await shown(p, "followup|")
        #expect(snooze.contains("|snooze"))
        #expect(await p.center.shown[snooze]?.notification.text.body == "Zinc")
        #expect(try await category(p, snooze) == .single)
        try await p.perform(.taken, on: snooze)
        #expect(await p.center.shown.isEmpty)
        await p.expectCorrect("the action of the snooze")
    }

    @Test func aRecordBeforeTheSnoozeFiresLeavesNoSnoozeBanner() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        await p.advance(to: "2026-10-15 09:01")
        try await p.perform(.snooze, on: try await shown(p, "series|"))
        #expect(await pendingIdentifiers(p, containing: "|snooze").count == 1)
        await p.advance(to: "2026-10-15 09:05")

        try await p.record("Zinc")

        #expect(await pendingIdentifiers(p, containing: "|snooze").isEmpty)
        await p.expectCorrect("the record removed the snooze")
        let before = await p.center.deliveries.count
        await p.advance(to: "2026-10-15 09:20")
        #expect(await p.center.deliveries.count == before, "no snooze banner for a closed dose")
        #expect(await p.center.shown.isEmpty)
        // An undo after the time brings no old snooze back: the record ended it.
        try await p.undo("Zinc")
        #expect(await pendingIdentifiers(p, containing: "|snooze").isEmpty)
        await p.expectCorrect("after the undo")
    }

    @Test func aSnoozePausesTheFollowUpsOfItsDoseUntilItsTime() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"], followUp: FollowUpSetting(count: .three, interval: .minutes5))
        p.checks.followUpCoverage = true
        await p.advance(to: "2026-10-15 09:01")
        #expect(await pendingIdentifiers(p, containing: "|2026-10-15|09:00|+").count == 3)

        try await p.perform(.snooze, on: try await shown(p, "series|"))

        // The snooze is for 09:11. The follow-ups at 09:05 and 09:10 wait, and the one at 09:15 stays.
        let followUps = await pendingIdentifiers(p, containing: "|2026-10-15|09:00")
        #expect(followUps.contains { $0.contains("|snooze") })
        #expect(followUps.contains { $0.contains("|+15") })
        #expect(!followUps.contains { $0.contains("|+5") || $0.contains("|+10") })
        await p.expectCorrect("the follow-ups wait for the snooze")
        await p.advance(to: "2026-10-15 09:16")
        p.expectCorrectDeliveries()
        await p.foreground()
        await p.expectCorrect("after the snooze and the later follow-up")
    }

    @Test func aSnoozeOfAGroupNamesTheOpenDosesOfItsGroup() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"], followUp: FollowUpSetting(count: .one, interval: .minutes30))
        await p.advance(to: "2026-10-15 09:01")
        try await p.perform(.snooze, on: try await shown(p, "series|"))
        // Iron is recorded during the snooze. The snooze names the other dose only.
        try await p.record("Iron")
        await p.expectCorrect("a group of two with one dose recorded")
        await p.advance(to: "2026-10-15 09:12")
        p.expectCorrectDeliveries()
        let snooze = try await shown(p, "followup|")
        #expect(await p.center.shown[snooze]?.notification.text.body == "Zinc")
    }

    @Test func aSnoozeAfterTheFollowUpsStoppedIsRefused() async throws {
        let p = try await phone("2026-10-15 22:00")
        try await p.addItem("Zinc", at: ["23:50"], followUp: FollowUpSetting(count: .one, interval: .minutes60))
        await p.advance(to: "2026-10-16 00:51")
        let id = try await shown(p, "followup|")

        // 00:51 and ten minutes is 01:01. The follow-ups of a dose end at 01:00, so the snooze would never come.
        #expect(try await p.perform(.snooze, on: id) == nil)

        #expect(await pendingIdentifiers(p, containing: "|snooze").isEmpty)
        await p.expectCorrect("no snooze after 01:00")
    }

    // MARK: Names hidden, and the oracle

    @Test func withTheNamesHiddenAGroupHasNoGroupAction() async throws {
        let p = try await phone()
        await p.setPrivacy(.hideNames)
        let setting = FollowUpSetting(count: .one, interval: .minutes15)
        try await p.addItem("Zinc", at: ["09:00"], followUp: setting)
        try await p.addItem("Iron", at: ["09:00"], followUp: setting)
        try await p.addItem("Copper", at: ["12:00"])
        for notification in await p.center.pending.values {
            let category = try #require(notification.presentation?.category)
            if notification.userInfo["seriesID"]?.contains("12:00") == true {
                // One item: the actions of D034 stay, also with the names hidden.
                #expect(category == .single)
            } else {
                #expect(category == .snooze, "\(notification.identifier) has \(category)")
                #expect(!category.actions.contains(.taken) && !category.actions.contains(.skip))
            }
        }
        await p.expectCorrect("names hidden")
        // A snooze writes no record, so it still works.
        await p.advance(to: "2026-10-15 09:01")
        try await p.perform(.snooze, on: try await shown(p, "series|"))
        await p.expectCorrect("a snooze with the names hidden")
    }

    @Test func theOracleSeesAWrongCategoryAndAWrongLevel() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        try await p.addItem("Iron", at: ["09:00"])
        await p.expectCorrect("setup")
        let id = try #require(await p.center.pending.keys.first { $0.hasPrefix("series|") })
        let held = try #require(await p.center.pending[id])
        for wrong in [
            ReminderPresentation(category: .single),
            ReminderPresentation(category: .snooze),
            ReminderPresentation(category: .group, level: .active),
        ] {
            await p.center.inject(SimNotification(
                identifier: id, text: held.text, userInfo: held.userInfo, presentation: wrong, threadIdentifier: nil, trigger: held.trigger
            ))
            let found = await p.violations()
            #expect(found.contains { $0.contains("category") || $0.contains("level") }, "\(wrong) was not found: \(found)")
        }
    }

    // MARK: Update from version 1.1

    @Test func aPendingRequestOfVersion11WithTheOldCategoryIsReplacedAtTheFirstRun() async throws {
        let p = try await phone()
        try await p.addItem("Zinc", at: ["09:00"])
        let id = try #require(await p.center.pending.keys.first { $0.hasPrefix("series|") })
        let held = try #require(await p.center.pending[id])
        // Version 1.1 registered one category, `reminder.single`. This build does not know it.
        await p.center.inject(SimNotification(
            identifier: id, text: held.text, userInfo: held.userInfo, presentation: nil, threadIdentifier: nil, trigger: held.trigger
        ))
        p.terminate()

        await p.foreground()

        await p.expectCorrect("the first run of the new build")
        let now = await p.center.pending.values.filter { $0.identifier.hasPrefix("series|") }
        #expect(now.count == 1 && now[0].presentation?.category == .single)
    }
}
