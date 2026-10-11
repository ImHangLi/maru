import Foundation
import MaruCore
import Testing
@testable import MaruDatabase

struct HistoryTests {
    /// D019: a record stays in the history after the plan drops its slot. A planned dose with no record shows as such.
    @Test func recordOfADoseThatIsNoLongerPlannedStillShows() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.versionID)
        // From the same date, the plan has only the evening slot.
        var schedule = seed.schedule
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: Fixtures.date(2026, 3, 1),
                weeklyRule: .everyDay,
                slotTimes: [SlotTime(slotID: seed.evening, time: Fixtures.time(20))],
                timeZonePolicy: .fixed(Fixtures.shanghai)
            )
        )
        try await store.save(schedule)

        let page = try await store.history(before: Fixtures.date(2026, 3, 2), days: 1, deviceTimeZone: Fixtures.shanghai)

        let doses = try #require(page.days.first { $0.date == Fixtures.date(2026, 3, 1) }).doses
        #expect(doses.map(\.occurrence.slotID) == [seed.morning, seed.evening])
        #expect(doses.map(\.record.status) == [.taken, .unrecorded])
        #expect(doses.map(\.isStored) == [true, false])
    }

    /// Spec 3 P05, D014: a backfill stores one occurrence and one event, also when the same pair goes again.
    @Test func backfillOfOnePastDoseStoresItOnceAlsoOnARetry() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let day = Fixtures.date(2026, 2, 20)
        let page = try await store.history(before: day.adding(days: 1), days: 1, deviceTimeZone: Fixtures.shanghai)
        let dose = try #require(page.days.first?.doses.first { $0.occurrence.slotID == seed.evening })
        #expect(!dose.isStored)
        let event = Fixtures.event(for: dose.occurrence, .taken)

        try await store.recordBackfill(event, occurrence: dose.occurrence)
        try await store.recordBackfill(event, occurrence: dose.occurrence)

        #expect(try await store.count("occurrence") == 2)
        try await store.expectConsistent(dose.occurrence, events: [event], status: .taken)
        let after = try await store.history(before: day.adding(days: 1), days: 1, deviceTimeZone: Fixtures.shanghai)
        let stored = try #require(after.days.first?.doses.first { $0.occurrence.slotID == seed.evening })
        #expect(stored.isStored && stored.occurrence == dose.occurrence && stored.record.status == .taken)
    }

    /// D021: an as-needed dose (no slot) shows on its day with its own item, next to the planned doses.
    @Test func asNeededDoseShowsOnItsDay() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let item = try Item(category: .supplement, name: "Ibuprofen", form: .tablet, color: .orange)
        try await store.save(item)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: item.id, at: now, in: Fixtures.shanghai)
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)
        let record = try await store.recordAsNeeded(taken, occurrence: dose)

        let page = try await store.history(before: Fixtures.date(2026, 3, 2), days: 1, deviceTimeZone: Fixtures.shanghai)

        let day = try #require(page.days.first { $0.date == Fixtures.date(2026, 3, 1) })
        #expect(day.asNeeded == [HistoryAsNeededDose(occurrence: dose, record: record)])
        #expect(day.doses.allSatisfy { $0.itemID == seed.schedule.itemID })
    }

    /// Spec 7.3: an old record with a missing projection row stays reachable. Its page reports `invalidData`.
    @Test func oldRecordWithABrokenProjectionIsReportedNotHidden() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let item = try Item(category: .supplement, name: "Ibuprofen", form: .tablet, color: .orange)
        try await store.save(item)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: item.id, at: now, in: Fixtures.shanghai)
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)
        try await store.recordAsNeeded(taken, occurrence: dose)
        try await store.execute("DELETE FROM occurrenceState")
        let today = Fixtures.date(2026, 4, 15)

        let page = try await store.history(before: today, days: 30, deviceTimeZone: Fixtures.shanghai)

        #expect(page.hasEarlier)
        await #expect(throws: StorageError.invalidData) {
            try await store.history(before: today, days: 60, deviceTimeZone: Fixtures.shanghai)
        }
    }
}
