import Foundation
import Testing
@testable import MaruCore

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
}
