import Foundation
import Testing
@testable import MaruCore
@testable import MaruDatabase

/// D088: the update path. Each file in `Fixtures` is a database that a shipped version of the app left after real use.
/// The current code opens it (the store migrates it), copies the global "Remind Again" setting of version 1.0 to the
/// items as the first open does, and runs the whole reminder queue. Every later migration adds its own fixture.
@Suite("Upgrade from a shipped version")
struct UpgradeTests {
    static let fixtures = ["v5-build4-1.0", "v6-build7-1.1"]

    static func url(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "sqlite"))
    }

    @Test(arguments: fixtures) func theReminderRunWorksAfterTheUpdate(_ name: String) async throws {
        for legacy: FollowUpSetting? in [nil, FollowUpSetting(count: .untilRecorded, interval: .minutes30)] {
            let p = try await Phone.make(start: "2026-10-15 23:50", fixture: Self.url(name))
            p.checkOracle = false
            if let legacy { try await p.store.adoptFollowUpSetting(legacy, changed: .distantFuture) }
            await p.launch()
            #expect(p.lastError == nil, "the run threw \(String(describing: p.lastError))")
            #expect(p.lastOutcome?.followUps != nil, "the follow-up refresh failed")
            await p.advance(to: "2026-10-16 00:05")
            await p.foreground()
            #expect(p.lastError == nil, "the run threw \(String(describing: p.lastError))")
            #expect(await p.center.pending.count > 0)
        }
    }

    /// D091 (migration v7): an old database has no archive time and no as-needed amount. Every item loads, and an as-needed dose
    /// that the new code records keeps its amount in the history and in the export.
    @Test(arguments: fixtures) func theTrackerColumnsLoadAndAnAsNeededDoseKeepsItsAmount(_ name: String) async throws {
        let p = try await Phone.make(start: "2026-10-16 09:00", fixture: Self.url(name))
        let items = try await p.store.items()
        #expect(!items.isEmpty && items.allSatisfy { $0.archivedAt == nil && $0.asNeededDose == nil })
        let zone = try NamedTimeZone(identifier: "Asia/Shanghai")
        let now = Date()
        let dose = AsNeededOccurrence(itemID: items[0].id, at: now, in: zone, dose: Dose("400 mg"))
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)
        try await p.store.recordAsNeeded(taken, occurrence: dose)

        let today = LocalDate(now, in: zone)
        let page = try await p.store.history(before: today.adding(days: 1), days: 1, deviceTimeZone: zone)
        let doses = try #require(page.days.first).asNeeded
        // A dose that the old version recorded has no amount. The new one has its amount.
        #expect(doses.last?.occurrence.dose == Dose("400 mg") && doses.dropLast().allSatisfy { $0.occurrence.dose == nil })
        let lines = try await p.store.exportedDoses(through: today, deviceTimeZone: zone)
        #expect(lines.contains { $0.plannedTime == nil && $0.dose == Dose("400 mg") })
        #expect(try await p.store.asNeeded(on: today).lastTaken[items[0].id] != nil)
    }
}
