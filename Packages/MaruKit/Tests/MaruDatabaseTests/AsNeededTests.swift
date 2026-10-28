import Foundation
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("As-needed items (D021, spec 7.2)")
struct AsNeededTests {
    let directory = TestDirectory()

    /// One tap makes one occurrence and one event. The commit works and the full flush fails, so the call
    /// gives `unavailable`. The retry with the same occurrence and event adds nothing (D014).
    @Test func oneTapGivesOneOccurrenceAndOneEventAlsoOnARetry() async throws {
        let store = try LocalStore(directory: directory.url)
        let item = try Item(personID: store.meID, category: .supplement, name: "Ibuprofen", form: .tablet, color: .orange)
        try await store.save(item)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: item.id, at: now, in: Fixtures.shanghai)
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)

        await #expect(throws: RecordFailure.storage(.unavailable)) {
            try await store.recordAsNeeded(taken, occurrence: dose) { _ in -1 }
        }
        let record = try await store.recordAsNeeded(taken, occurrence: dose)

        #expect(record.events == [taken])
        #expect(try await store.count("occurrence") == 1)
        #expect(try await store.count("intakeEvent") == 1)
        let today = try await store.asNeeded(on: Fixtures.date(2026, 3, 1))
        #expect(today.items == [item])
        #expect(today.records == [AsNeededRecord(occurrence: dose, record: record)])
    }

    /// A taken dose whose projection row is gone is `invalidData`. The read does not hide it as undone (spec 7.3).
    @Test func aDoseWithABrokenProjectionIsReportedNotHidden() async throws {
        let store = try LocalStore(directory: directory.url)
        let item = try Item(personID: store.meID, category: .supplement, name: "Ibuprofen", form: .tablet, color: .orange)
        try await store.save(item)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: item.id, at: now, in: Fixtures.shanghai)
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)
        try await store.recordAsNeeded(taken, occurrence: dose)
        try await store.execute("DELETE FROM occurrenceState")

        await #expect(throws: StorageError.invalidData) {
            try await store.asNeeded(on: Fixtures.date(2026, 3, 1))
        }
    }
}
