import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("Stored occurrence generation (spec 7.2, 7.3, 8.1, T16, T17, T26)")
struct GenerationTests {
    let directory = TestDirectory()

    // 1 March 2026 is a Sunday. The schedule has 08:00 and 20:00 in Shanghai, which is UTC+8.
    let yesterday = Fixtures.date(2026, 2, 28)
    let today = Fixtures.date(2026, 3, 1)
    let tomorrow = Fixtures.date(2026, 3, 2)
    /// 07:00, 12:00, and 22:00 on 1 March in Shanghai.
    let early = Fixtures.instant("2026-02-28T23:00:00Z")
    let noon = Fixtures.instant("2026-03-01T04:00:00Z")
    let late = Fixtures.instant("2026-03-01T14:00:00Z")

    /// A store with one item and its twice-daily schedule. No occurrence is stored.
    private func prepare(
        timeZonePolicy: TimeZonePolicy = .fixed(Fixtures.shanghai)
    ) async throws -> (store: LocalStore, item: Item, schedule: Schedule, morning: ScheduleSlotID, evening: ScheduleSlotID) {
        let store = try LocalStore(directory: directory.url)
        let item = try Item(personID: store.meID, category: .medication, name: "Metformin", form: .capsule, color: .pink)
        try await store.save(item)
        let (schedule, morning, evening) = Fixtures.twiceDailySchedule(itemID: item.id, timeZonePolicy: timeZonePolicy)
        try await store.save(schedule)
        return (store, item, schedule, morning, evening)
    }

    private func generate(_ store: LocalStore, at now: Date, device: NamedTimeZone = Fixtures.shanghai) async throws -> [Occurrence] {
        try await store.generateOccurrences(at: now, deviceTimeZone: device)
    }

    // MARK: The window and a second run

    @Test func secondRunCreatesNoSecondOccurrence() async throws {
        let (store, _, _, _, _) = try await prepare()
        let first = try await generate(store, at: early)

        for now in [early, noon, late] {
            #expect(try await generate(store, at: now) == first)
        }
        // Runs at the same time, for example from the app and from a notification action.
        try await withThrowingTaskGroup(of: [Occurrence].self) { group in
            for _ in 0..<10 {
                group.addTask { try await store.generateOccurrences(at: noon, deviceTimeZone: Fixtures.shanghai) }
            }
            for try await occurrences in group {
                #expect(occurrences == first)
            }
        }
        #expect(try await store.count("occurrence") == 6)

        // The same database after the app starts again.
        try store.writer.close()
        let reopened = try LocalStore(directory: directory.url)
        #expect(try await generate(reopened, at: noon) == first)
        #expect(try await reopened.count("occurrence") == 6)
    }

    @Test func eachDayAddsOnlyOneDateOfRows() async throws {
        let (store, _, _, morning, _) = try await prepare()
        _ = try await generate(store, at: noon)
        #expect(try await store.count("occurrence") == 6)

        _ = try await generate(store, at: Fixtures.instant("2026-03-02T04:00:00Z"))
        #expect(try await store.count("occurrence") == 8)
        // A month later the run does not fill the days between.
        let occurrences = try await generate(store, at: Fixtures.instant("2026-04-01T04:00:00Z"))
        #expect(Set(occurrences.map(\.plannedDate)) == [Fixtures.date(2026, 3, 31), Fixtures.date(2026, 4, 1), Fixtures.date(2026, 4, 2)])
        #expect(try await store.count("occurrence") == 14)
        #expect(try await store.occurrence(slotID: morning, on: Fixtures.date(2026, 3, 15)) == nil)
        #expect(try await store.occurrence(slotID: morning, on: Fixtures.date(2026, 4, 3)) == nil)
    }

    // MARK: T16

    @Test func morningAndEveningKeepSeparateRecords() async throws {
        let (store, _, _, morning, evening) = try await prepare()
        let occurrences = try await generate(store, at: early)
        let morningDose = try #require(occurrences.first { $0.slotID == morning && $0.plannedDate == today })
        let eveningDose = try #require(occurrences.first { $0.slotID == evening && $0.plannedDate == today })
        #expect(morningDose.id != eveningDose.id)

        let taken = Fixtures.event(for: morningDose, .taken)
        try await store.record(taken, scheduleVersionID: morningDose.scheduleVersionID)
        #expect(try await generate(store, at: noon) == occurrences)
        try await store.expectConsistent(morningDose, events: [taken], status: .taken)
        try await store.expectConsistent(eveningDose, events: [], status: .unrecorded)

        let skipped = Fixtures.event(for: eveningDose, .skipped)
        try await store.record(skipped, scheduleVersionID: eveningDose.scheduleVersionID)
        #expect(try await generate(store, at: late) == occurrences)
        try await store.expectConsistent(morningDose, events: [taken], status: .taken)
        try await store.expectConsistent(eveningDose, events: [skipped], status: .skipped)
    }

    // MARK: T17, a schedule change in the middle of a day, and the past

    @Test func editOfARecordedMorningCreatesNoSecondMorning() async throws {
        var (store, _, schedule, morning, evening) = try await prepare()
        let original = try #require(schedule.versions.first)
        let before = try await generate(store, at: early)
        let morningDose = try #require(before.first { $0.slotID == morning && $0.plannedDate == today })
        let eveningDose = try #require(before.first { $0.slotID == evening && $0.plannedDate == today })
        let taken = Fixtures.event(for: morningDose, .taken)
        try await store.record(taken, scheduleVersionID: original.id)

        // At noon the user moves the morning time to 09:30, from today.
        let edited = try schedule.changeTime(of: morning, to: Fixtures.time(9, 30), effectiveFrom: today)
        try await store.save(schedule)
        let after = try await generate(store, at: noon)

        // No new row. The recorded morning keeps its ID, its time, its version, and its record.
        #expect(try await store.count("occurrence") == 6)
        #expect(after.filter { $0.slotID == morning && $0.plannedDate == today } == [morningDose])
        #expect(try await store.occurrence(slotID: morning, on: today) == morningDose)
        #expect(morningDose.plannedTime == Fixtures.time(8))
        try await store.expectConsistent(morningDose, events: [taken], status: .taken)
        // A second record for the morning of today is still rejected.
        await #expect(throws: RecordFailure.rejected(.alreadyRecorded)) {
            try await store.record(Fixtures.event(for: morningDose, .taken), scheduleVersionID: original.id)
        }
        // The evening of today has no record. It keeps its ID and gets the version in force.
        let eveningAfter = try #require(after.first { $0.slotID == evening && $0.plannedDate == today })
        #expect(eveningAfter.id == eveningDose.id)
        #expect(eveningAfter.plannedTime == Fixtures.time(20))
        #expect(eveningAfter.scheduleVersionID == edited.id)
        // Tomorrow has the new time, and yesterday keeps the old one.
        #expect(try await store.occurrence(slotID: morning, on: tomorrow)?.plannedTime == Fixtures.time(9, 30))
        #expect(try await store.occurrence(slotID: morning, on: yesterday)?.plannedTime == Fixtures.time(8))
        #expect(try await store.occurrence(slotID: morning, on: yesterday)?.scheduleVersionID == original.id)
    }

    @Test func editInTheMiddleOfADayMovesADoseWithNoRecord() async throws {
        var (store, _, schedule, morning, _) = try await prepare()
        let original = try #require(schedule.versions.first)
        let before = try #require(try await generate(store, at: early).first { $0.slotID == morning && $0.plannedDate == today })

        let edited = try schedule.changeTime(of: morning, to: Fixtures.time(9, 30), effectiveFrom: today)
        try await store.save(schedule)
        let occurrences = try await generate(store, at: noon)

        let after = try #require(occurrences.first { $0.slotID == morning && $0.plannedDate == today })
        #expect(occurrences.filter { $0.slotID == morning && $0.plannedDate == today }.count == 1)
        #expect(try await store.count("occurrence") == 6)
        #expect(after.id == before.id)
        #expect(after.plannedTime == Fixtures.time(9, 30))
        #expect(after.scheduleVersionID == edited.id)
        #expect(try await store.occurrence(id: before.id) == after)
        #expect(try await generate(store, at: noon) == occurrences)

        // A screen that still shows the old version cannot record. With the version in force, the record works.
        let taken = Fixtures.event(for: after, .taken)
        await #expect(throws: RecordFailure.versionChanged) {
            try await store.record(taken, scheduleVersionID: original.id)
        }
        try await store.record(taken, scheduleVersionID: edited.id)
        try await store.expectConsistent(after, events: [taken], status: .taken)
    }

    /// A record of the widget or the Watch reads the clock in its transaction. A request from before midnight
    /// that gets the writer after it records nothing for yesterday (D071).
    @Test func recordInTheCurrentPlanReadsTheClockInTheTransaction() async throws {
        let (store, _, _, _, evening) = try await prepare()
        let dose = try #require(try await generate(store, at: late).first { $0.slotID == evening && $0.plannedDate == today })
        let afterMidnight = Fixtures.instant("2026-03-01T16:01:00Z")
        await #expect(throws: RecordFailure.versionChanged) {
            try await store.record(
                [(Fixtures.event(for: dose, .taken), dose.scheduleVersionID)],
                currentPlan: { OccurrenceGeneration(now: afterMidnight, deviceTimeZone: Fixtures.shanghai) }
            )
        }
        #expect(try await store.count("intakeEvent") == 0)
    }

    @Test func occurrenceWithAnUndoneRecordFollowsThePlan() async throws {
        var (store, _, schedule, morning, _) = try await prepare()
        let before = try #require(try await generate(store, at: early).first { $0.slotID == morning && $0.plannedDate == today })
        let taken = Fixtures.event(for: before, .taken)
        let undo = Fixtures.event(for: before, .undo, supersedes: taken.id)
        try await store.record(taken, scheduleVersionID: before.scheduleVersionID)
        try await store.record(undo, scheduleVersionID: before.scheduleVersionID)

        try schedule.changeTime(of: morning, to: Fixtures.time(9, 30), effectiveFrom: today)
        try await store.save(schedule)
        let occurrences = try await generate(store, at: noon)

        // An undo leaves no record, so the open dose moves to the new time and keeps its ID (D095).
        let after = try #require(occurrences.first { $0.slotID == morning && $0.plannedDate == today })
        #expect(after.id == before.id && after.plannedTime == Fixtures.time(9, 30))
        try await store.expectConsistent(after, events: [taken, undo], status: .unrecorded)
        #expect(try await store.count("occurrence") == 6)
    }

    @Test func editDoesNotRewriteAPastDate() async throws {
        var (store, _, schedule, morning, _) = try await prepare()
        let before = try await generate(store, at: noon)

        // On 2 March the user gives the new version a start on 1 March. Nothing of 1 March has a record.
        try schedule.changeTime(of: morning, to: Fixtures.time(9, 30), effectiveFrom: today)
        try await store.save(schedule)
        let after = try await generate(store, at: Fixtures.instant("2026-03-02T04:00:00Z"))

        #expect(after.filter { $0.plannedDate == today } == before.filter { $0.plannedDate == today })
        #expect(try await store.occurrence(slotID: morning, on: yesterday) == before.first)
        #expect(try await store.occurrence(slotID: morning, on: tomorrow)?.plannedTime == Fixtures.time(9, 30))
    }

    @Test func deviceZoneChangeDoesNotRewriteAPastDate() async throws {
        let (store, _, _, _, _) = try await prepare(timeZonePolicy: .followsDevice)
        let before = try await generate(store, at: noon, device: Fixtures.shanghai)

        // A day later the device is in New York. It is 2 March in Shanghai and still 1 March in New York.
        let after = try await generate(store, at: Fixtures.instant("2026-03-02T04:00:00Z"), device: Fixtures.newYork)

        // 1 March is over in the zone of the stored occurrences, so they keep their zone and their instant.
        #expect(after.filter { $0.plannedDate <= today } == before.filter { $0.plannedDate <= today })
        for occurrence in before where occurrence.plannedDate <= today {
            #expect(try await store.occurrence(id: occurrence.id) == occurrence)
        }
        // 2 March is not in the past in the two zones. Its doses follow the device and keep their IDs.
        let moved = after.filter { $0.plannedDate == tomorrow }
        #expect(moved.map(\.id) == before.filter { $0.plannedDate == tomorrow }.map(\.id))
        #expect(moved.allSatisfy { $0.timeZone == Fixtures.newYork })
        #expect(try await store.count("occurrence") == 6)
    }
}
