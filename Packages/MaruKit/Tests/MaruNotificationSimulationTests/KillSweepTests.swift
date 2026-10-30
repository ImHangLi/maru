import Foundation
import Testing
@testable import MaruCore

/// Each scenario stops the reminder run at each external call after the data commits.
/// After restart, fresh request identifiers and generations must restore correct notifications before delivery (D086).
@Suite("A run that stops anywhere")
struct KillSweepTests {
    private static let evening = "2026-10-15 18:00"

    private func setup() async throws -> Phone {
        let phone = try await Phone.make(start: "2026-10-14 12:00")
        try await phone.addItem("Coenzyme Q10", at: ["09:00", "16:00", "21:00"], followUp: FollowUpSetting(count: .two, interval: .minutes30))
        try await phone.addItem("Vitamin B Complex", at: ["09:00"])
        try await phone.addItem("Magnesium Glycinate", at: ["21:00"])
        try await phone.addItem("Fish Oil", at: ["21:00"], followUp: FollowUpSetting(count: .three, interval: .minutes15))
        try await phone.addItem("Zinc", at: ["20:00", "22:00"], days: .weekdays([.monday, .thursday]))
        await phone.advance(to: "2026-10-15 09:01")
        await phone.foreground()
        await phone.advance(to: Self.evening)
        await phone.foreground()
        await phone.expectCorrect("setup")
        return phone
    }

    /// Runs `action` with a stop at each call of its run, then one normal start, then checks the notifications.
    private func sweep(
        _ label: String, sourceLocation: SourceLocation = #_sourceLocation, _ action: (Phone) async throws -> Void
    ) async throws {
        var stuck: [Int] = []
        var details: [String] = []
        for call in 1...200 {
            let phone = try await setup()
            phone.nextRunKillsAtCall = call
            // The first runs after the stop can be wrong for a moment. The check is below, after the second start.
            phone.autoCheck = false
            try await action(phone)
            let used = phone.callsInLastRun
            // Restart before delivery, then check recovery from the interrupted run.
            await phone.advance(to: phone.now.addingTimeInterval(60))
            await phone.foreground()
            await phone.foreground()
            let found = await phone.violations()
            if !found.isEmpty {
                stuck.append(call)
                if details.count < 2 { details.append("stop at call \(call) of \(used):\n" + found.prefix(6).joined(separator: "\n")) }
            }
            if used < call { break }
        }
        #expect(stuck.isEmpty, "\(label): wrong after a stop at calls \(stuck)\n\(details.joined(separator: "\n"))", sourceLocation: sourceLocation)
    }

    @Test func archiveOfAnItemWithFollowUps() async throws {
        try await sweep("archive") { try await $0.archive("Fish Oil") }
    }

    @Test func recordBeforeTheTimeOfADailyReminder() async throws {
        try await sweep("record before the time") { try await $0.record("Magnesium Glycinate") }
    }

    @Test func undoBeforeTheTime() async throws {
        try await sweep("undo") { phone in
            try await phone.record("Magnesium Glycinate")
            await phone.advance(to: phone.now.addingTimeInterval(10))
            try await phone.undo("Magnesium Glycinate")
        }
    }

    @Test func editOfTheTime() async throws {
        try await sweep("time edit") { try await $0.changeTime("Magnesium Glycinate", to: "22:30") }
    }

    @Test func pause() async throws {
        try await sweep("pause") { try await $0.pause("Magnesium Glycinate") }
    }

    @Test func delete() async throws {
        try await sweep("delete") { try await $0.delete("Fish Oil") }
    }

    @Test func remindAgainForAllItems() async throws {
        try await sweep("remind again off for all") { try await $0.setAllFollowUp(nil) }
    }
}
