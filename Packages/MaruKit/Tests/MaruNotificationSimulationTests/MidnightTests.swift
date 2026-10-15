import Foundation
import Testing
@testable import MaruCore

/// D088: times at and near midnight, checked with a fake center that validates triggers as iOS does.
/// `Phone.run` fails a scenario when a run throws, a schedule is "not set", or the oracle finds a wrong request.
@Suite("Midnight reminders")
struct MidnightTests {
    struct Setup: CustomTestStringConvertible, Sendable {
        let clock: String
        let followUp: FollowUpSetting?
        let alarm: Bool
        var testDescription: String {
            "\(clock) followUp=\(followUp.map { "\($0.count)@\($0.interval.rawValue)" } ?? "off") alarm=\(alarm)"
        }
    }

    static let setups: [Setup] = {
        let settings: [FollowUpSetting?] = [
            nil, FollowUpSetting(count: .three, interval: .minutes30), FollowUpSetting(count: .untilRecorded, interval: .minutes5),
        ]
        return ["2026-10-15 23:50", "2026-10-15 23:53", "2026-10-16 00:05"].flatMap { clock in
            settings.flatMap { setting in [false, true].map { Setup(clock: clock, followUp: setting, alarm: $0) } }
        }
    }()

    @Test(arguments: setups) func addMidnightToAnItemWithAMorningTime(_ s: Setup) async throws {
        let p = try await Phone.make(start: s.clock)
        try await p.addItem("Vitamin B Complex", at: ["08:00"], followUp: s.followUp, alarm: s.alarm)
        try await p.addTime("Vitamin B Complex", "00:00")
        try await p.addTime("Vitamin B Complex", "10:00")
        try await p.changeTime("Vitamin B Complex", slot: 0, to: "00:00")
    }

    @Test(arguments: setups) func addElevenPmToAnItemWithThreeTimes(_ s: Setup) async throws {
        let p = try await Phone.make(start: s.clock)
        try await p.addItem("Coenzyme Q10", at: ["09:00", "16:00", "21:00"], followUp: s.followUp, alarm: s.alarm)
        try await p.addTime("Coenzyme Q10", "23:00")
        try await p.addTime("Coenzyme Q10", "23:59")
        await p.advance(to: "2026-10-16 01:30")
        p.expectCorrectDeliveries()
    }

    @Test(arguments: setups) func manyItemsWithManyTimes(_ s: Setup) async throws {
        let p = try await Phone.make(start: s.clock)
        for (index, name) in ["Zinc", "Iron", "Fish Oil", "Magnesium"].enumerated() {
            try await p.addItem(name, at: ["09:00", "16:00", "21:00"], followUp: s.followUp, alarm: s.alarm && index == 0)
        }
        try await p.addItem("Coenzyme Q10", at: ["09:00", "16:00", "21:00"], followUp: s.followUp, alarm: s.alarm)
        try await p.addTime("Coenzyme Q10", "23:00")
        try await p.addItem("Vitamin B Complex", at: ["00:00", "08:00"], followUp: s.followUp, alarm: s.alarm)
    }

    /// One request that the system refuses does not fail the run. The other requests stay, and only the schedule of the
    /// refused request is "not set" (D088).
    @Test func oneRefusedRequestDoesNotStopTheOthers() async throws {
        let p = try await Phone.make(start: "2026-10-15 23:53")
        p.autoCheck = false
        await p.center.setRejects("|00:00|")
        try await p.addItem("Zinc", at: ["09:00", "21:00"])
        try await p.addItem("Vitamin B Complex", at: ["00:00", "08:00"])
        #expect(p.lastError == nil)
        let states = try #require(p.lastOutcome).reminders.schedules
        #expect(states.values.filter { $0 == .scheduled }.count == 1)
        #expect(states.values.filter { $0 == .notSet(.notRegistered) }.count == 1)
        let pending = await p.center.pending.keys
        #expect(pending.contains { $0.contains("|21:00|") } && pending.contains { $0.contains("|08:00|") })
    }

    @Test func theFakeRejectsATriggerThatCannotFire() async throws {
        let p = try await Phone.make(start: "2026-10-15 23:53")
        let past = ReminderRequest(
            identifier: "series|device|23:00|2026-10-15",
            trigger: ReminderTrigger(time: Phone.wallClock("23:00"), weekday: nil, date: p.today(), timeZone: nil),
            content: ReminderContent(kind: .due, names: ["Zinc"]), userInfo: [:], fireDate: nil
        )
        await #expect(throws: SimError.self) { try await p.center.add(past) }
    }
}
