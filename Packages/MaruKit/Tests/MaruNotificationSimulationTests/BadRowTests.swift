import Foundation
import Testing
@testable import MaruCore

/// D088: a schedule that does not load stops no other reminder, and the run removes no request because of it.
@Suite("A row that does not load")
struct BadRowTests {
    @Test func theOtherItemsKeepTheirRemindersAndNothingIsRemoved() async throws {
        let p = try await Phone.make(start: "2026-10-15 12:00")
        p.autoCheck = false
        try await p.addItem("Zinc", at: ["09:00"], followUp: FollowUpSetting(count: .two, interval: .minutes30))
        try await p.addItem("Iron", at: ["21:00"], followUp: FollowUpSetting(count: .two, interval: .minutes30))
        let before = await p.center.pending.keys.filter { $0.contains("|21:00|") }
        #expect(!before.isEmpty)

        try await p.corruptSchedule("Iron")
        try await p.rename("Zinc", to: "Zinc B")
        #expect(p.lastError == nil)
        let outcome = try #require(p.lastOutcome)
        #expect(outcome.reminders.schedules.values.filter { $0 == .scheduled }.count == 1)
        #expect(outcome.reminders.schedules.values.filter { $0 == .notSet(.unreadable) }.count == 1)
        // The request of the bad schedule stays, and the others follow the change.
        let pending = await p.center.pending
        #expect(Set(before).isSubset(of: Set(pending.keys)))
        #expect(pending.values.contains { $0.identifier.contains("|09:00|") && $0.text.body == "Zinc B" })
    }

    /// D089: with one unreadable schedule, the alarm of an archived item still goes, and the alarm of the unreadable schedule stays.
    @Test func anUnreadableScheduleKeepsOnlyItsOwnAlarms() async throws {
        let p = try await Phone.make(start: "2026-10-15 12:00")
        p.autoCheck = false
        try await p.addItem("Zinc", at: ["09:00"], alarm: true)
        try await p.addItem("Iron", at: ["21:00"], alarm: true)
        let before = await p.alarmCenter.alarms.values.map(\.names)
        #expect(before.contains { $0 == ["Zinc"] } && before.contains { $0 == ["Iron"] })

        try await p.corruptSchedule("Iron")
        try await p.archive("Zinc")
        let after = await p.alarmCenter.alarms.values.map(\.names)
        #expect(!after.contains { $0 == ["Zinc"] }, "the alarm of the archived item still waits")
        #expect(after.contains { $0 == ["Iron"] }, "the alarm of the unreadable schedule was cancelled")
    }
}
