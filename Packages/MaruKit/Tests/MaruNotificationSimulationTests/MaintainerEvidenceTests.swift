import Foundation
import Testing
@testable import MaruCore

/// The two notifications that the maintainer saw on the iPhone on 2026-10-15 (D086).
@Suite("Maintainer evidence, 2026-10-15")
struct MaintainerEvidenceTests {
    /// The data of the screenshots. Device time zone Australia/Sydney. Every item follows the device.
    private func evidenceDay() async throws -> Phone {
        let phone = try await Phone.make(start: "2026-10-14 12:00")
        try await phone.addItem("Coenzyme Q10", at: ["09:00", "16:00", "21:00"])
        try await phone.addItem("Vitamin B Complex", at: ["09:00"])
        try await phone.addItem("Creatine Monohydrate", at: ["09:00"])
        try await phone.addItem("Magnesium Glycinate", at: ["21:00"])
        try await phone.addItem("Fish Oil", at: ["21:00"])
        await phone.expectCorrect("after setup")
        // Yesterday evening the maintainer archives Fish Oil.
        await phone.advance(to: "2026-10-14 19:30")
        try await phone.archive("Fish Oil")
        await phone.expectCorrect("after the archive of Fish Oil")
        return phone
    }

    @Test func aFirstReminderOfRecordedDosesIsNotLeftInNotificationCenter() async throws {
        let phone = try await evidenceDay()
        await phone.advance(to: "2026-10-15 09:01")
        #expect(await phone.center.shown.keys.contains { $0.hasPrefix("series|device|09:00") })
        // 14:17: the three morning doses are recorded in the app.
        await phone.advance(to: "2026-10-15 14:17")
        for name in ["Coenzyme Q10", "Vitamin B Complex", "Creatine Monohydrate"] {
            try await phone.record(name)
        }
        await phone.expectCorrect("after the three records of the morning")
        #expect(!(await phone.center.shown.keys.contains { $0.hasPrefix("series|device|09:00") }))
    }

    @Test func theNineOClockNotificationNamesOnlyWhatIsStillOpen() async throws {
        let phone = try await evidenceDay()
        await phone.advance(to: "2026-10-15 09:01")
        await phone.advance(to: "2026-10-15 14:17")
        for name in ["Coenzyme Q10", "Vitamin B Complex", "Creatine Monohydrate"] {
            try await phone.record(name)
        }
        await phone.advance(to: "2026-10-15 18:44")
        try await phone.record("Magnesium Glycinate")
        await phone.expectCorrect("after Magnesium at 18:44")
        await phone.advance(to: "2026-10-15 21:22")
        phone.expectCorrectDeliveries()
        let evening = await phone.center.shown.values.filter { $0.notification.identifier.hasPrefix("series|") && $0.notification.identifier.contains("21:00") }.max { $0.date < $1.date }
        #expect(evening?.notification.text.body == "Coenzyme Q10")
        await phone.foreground()
        await phone.expectCorrect("at 21:22")
    }
}

/// The save of a 4th time on the maintainer's iPhone showed "Reminder Not Set" (build 6, 2026-10-15 21:53).
/// The run must end with every schedule "scheduled", for each setting that the maintainer may have (D086).
@Suite("Save of a fourth time")
struct FourthTimeTests {
    static let settings: [(String, FollowUpSetting?, Bool, Bool)] = [
        ("no follow-up, no alarm", nil, false, true),
        ("3 times, no alarm", FollowUpSetting(count: .three, interval: .minutes15), false, true),
        ("until recorded, 5 minutes", FollowUpSetting(count: .untilRecorded, interval: .minutes5), false, true),
        ("until recorded, alarm on and allowed", FollowUpSetting(count: .untilRecorded, interval: .minutes15), true, true),
        ("until recorded, alarm on and refused", FollowUpSetting(count: .untilRecorded, interval: .minutes15), true, false),
    ]

    @Test(arguments: settings) func theFourthTimeIsSet(_ setting: (String, FollowUpSetting?, Bool, Bool)) async throws {
        let (_, followUp, alarm, allowed) = setting
        let p = try await Phone.make(start: "2026-10-15 12:00")
        p.setAlarmsAllowed(allowed)
        try await p.addItem("Coenzyme Q10", at: ["09:00", "16:00", "21:00"], followUp: followUp, alarm: alarm)
        try await p.addItem("Vitamin B Complex", at: ["09:00"], followUp: followUp, alarm: alarm)
        try await p.addItem("Creatine Monohydrate", at: ["09:00"], followUp: followUp, alarm: alarm)
        try await p.addItem("Magnesium Glycinate", at: ["21:00"], followUp: followUp, alarm: alarm)
        try await p.addItem("Fish Oil", at: ["21:00"], followUp: followUp, alarm: alarm)
        try await p.archive("Fish Oil")
        for name in ["Coenzyme Q10", "Vitamin B Complex", "Creatine Monohydrate"] { try await p.record(name) }
        await p.advance(to: "2026-10-15 21:53")
        await p.foreground()
        try await p.addTime("Coenzyme Q10", "23:00")
        #expect(p.lastError == nil)
    }
}

/// Before D086, a persisted removal ledger blocked request repair after an interrupted removal.
/// Fresh request identifiers and generations now let later runs repair the system state.
@Suite("A removal that the system never did")
struct StuckRemovalTests {
    @Test func aStoppedRunDoesNotLeaveAnOldRequestForGood() async throws {
        // The run stops at each call in turn. Before D086, some of these stops left the old request for good.
        for call in 1...40 { try await scenario(stoppedAt: call) }
    }

    private func scenario(stoppedAt call: Int) async throws {
        let p = try await Phone.make(start: "2026-10-14 12:00")
        try await p.addItem("Coenzyme Q10", at: ["09:00", "21:00"])
        try await p.addItem("Vitamin B Complex", at: ["09:00"])
        try await p.addItem("Magnesium Glycinate", at: ["21:00"])
        try await p.addItem("Fish Oil", at: ["21:00"])
        // The user records Magnesium before 21:00. Its reminder run stops at the selected external call.
        await p.advance(to: "2026-10-14 18:00")
        p.nextRunKillsAtCall = call
        try await p.record("Magnesium Glycinate")
        p.terminate()
        // The user opens the app again before 21:00.
        await p.advance(to: "2026-10-14 18:30")
        await p.foreground()
        await p.foreground()
        // The next day: Fish Oil is archived, and the app runs normally from now on.
        await p.advance(to: "2026-10-15 09:01")
        await p.advance(to: "2026-10-15 12:00")
        try await p.archive("Fish Oil")
        await p.expectCorrect("the run after the archive")
        // 14:17: the morning doses are recorded. The 09:00 notification must leave Notification Center.
        await p.advance(to: "2026-10-15 14:17")
        try await p.record("Coenzyme Q10", slot: 0)
        try await p.record("Vitamin B Complex")
        #expect(!(await p.center.shown.keys.contains { $0.contains("|09:00|") }))
        await p.advance(to: "2026-10-15 18:44")
        try await p.record("Magnesium Glycinate")
        await p.advance(to: "2026-10-15 20:00")
        await p.advance(to: "2026-10-15 21:01")
        p.expectCorrectDeliveries()
        try await p.addTime("Coenzyme Q10", "23:00")
        #expect(p.lastOutcome?.reminders.schedules.values.allSatisfy { $0 == .scheduled || $0 == .off } == true)
    }
}
