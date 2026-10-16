import Foundation
import GRDB
import MaruCore
import SQLite3
import Testing
import os
@testable import MaruDatabase

@Suite("The record transaction (spec 7.2, T18, T19, T20)")
struct RecordTransactionTests {
    let directory = TestDirectory()

    // MARK: T18: one valid record, idempotent

    @Test func sameEventAgainWritesNothing() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let first = try await store.record(taken, scheduleVersionID: seed.versionID)
        let second = try await store.record(taken, scheduleVersionID: seed.versionID)
        #expect(first == second)
        #expect(try await store.count("intakeEvent") == 1)
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
    }

    @Test func manyEntryPointsAtTheSameTimeGiveOneValidRecord() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let events = (0..<20).map { _ in Fixtures.event(for: seed.occurrence, .taken) }
        let results = await withTaskGroup(of: Result<IntakeEvent, RecordFailure>.self) { group in
            for event in events {
                group.addTask {
                    do throws(RecordFailure) {
                        try await store.record(event, scheduleVersionID: seed.versionID)
                        return .success(event)
                    } catch {
                        return .failure(error)
                    }
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        let winners = results.compactMap { try? $0.get() }
        #expect(winners.count == 1)
        #expect(results.filter { $0 == .failure(.rejected(.alreadyRecorded)) }.count == 19)
        try await store.expectConsistent(seed.occurrence, events: winners, status: .taken)
    }

    @Test func takenActionOfAReminderRecordsItsOneDoseAndNeverASecondOne() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let plan = ReminderPlan(
            items: [seed.item], schedules: [seed.schedule], now: Fixtures.instant("2026-03-01T00:00:00Z"), deviceTimeZone: Fixtures.shanghai
        )
        let request = try #require(plan.requests.first { $0.trigger.time == Fixtures.time(8) })
        // Delivered at 08:00 in Shanghai on 1 March. The user chooses "Taken" at 08:10.
        let reminder = DeliveredReminder(
            deliveredAt: Fixtures.instant("2026-03-01T00:00:00Z"), userInfo: request.userInfo, triggerWeekday: nil
        )
        func act(_ reminder: DeliveredReminder, at now: String) async throws -> ReminderActionResult {
            try await store.recordOpenDoses(
                for: reminder, action: .taken, at: Fixtures.instant(now), deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
            )
        }

        // A follow-up records only the item and the schedule version that it was made for, also with the names hidden.
        var followUp = [
            ReminderRequest.seriesIDKey: plan.series[0].id,
            FollowUpRequest.plannedDateKey: "2026-03-01",
            FollowUpRequest.itemIDKey: ItemID().rawValue.uuidString,
            FollowUpRequest.scheduleVersionIDKey: seed.versionID.rawValue.uuidString,
        ]
        func followUpReminder() -> DeliveredReminder {
            DeliveredReminder(deliveredAt: Fixtures.instant("2026-03-01T00:30:00Z"), userInfo: followUp, triggerWeekday: nil)
        }
        let wrongItem = try await act(followUpReminder(), at: "2026-03-01T00:31:00Z")
        #expect(wrongItem.doses.isEmpty && wrongItem.recorded.isEmpty)
        #expect(try await store.count("intakeEvent") == 0)

        let result = try await act(reminder, at: "2026-03-01T00:10:00Z")
        // The dose is the morning dose of 1 March, not the evening dose and not a dose of another day.
        let recorded = try #require(result.recorded.first)
        #expect(result.recorded.count == 1 && result.notRecordedCount == 0 && result.isFlushed)
        #expect(recorded.record.occurrenceID == seed.occurrence.id)
        #expect(recorded.event.source == .notificationAction && recorded.event.action == .taken)

        // The action comes a second time: the dose has its record, and nothing is written.
        let again = try await act(reminder, at: "2026-03-01T00:11:00Z")
        #expect(again.recorded.isEmpty && again.unchangedCount == 1)
        // A follow-up of the right item finds the same closed dose.
        followUp[FollowUpRequest.itemIDKey] = seed.item.id.rawValue.uuidString
        let fromFollowUp = try await act(followUpReminder(), at: "2026-03-01T00:32:00Z")
        #expect(fromFollowUp.recorded.isEmpty && fromFollowUp.unchangedCount == 1)
        // A second event from a read before the first one is rejected (T18).
        await #expect(throws: RecordFailure.rejected(.alreadyRecorded)) {
            try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.versionID)
        }
        // On the next day the reminder is of another day, so the action records nothing (T15).
        let nextDay = try await act(reminder, at: "2026-03-02T00:10:00Z")
        #expect(nextDay.doses.isEmpty && nextDay.recorded.isEmpty)
        #expect(try await store.count("intakeEvent") == 1)
        try await store.expectConsistent(seed.occurrence, events: [recorded.event], status: .taken)
    }

    /// "Take All" (D090): one transaction records every named dose that is open. A dose that has a record stays as it is, and a skip is
    /// never replaced (D034).
    @Test func takeAllRecordsTheOpenDosesAndKeepsATakenAndASkippedDose() async throws {
        let store = try LocalStore(directory: directory.url)
        var items: [Item] = []
        var schedules: [Schedule] = []
        for name in ["Iron", "Zinc", "Copper"] {
            let item = try Item(category: .supplement, name: name, form: .capsule, color: .pink)
            try await store.save(item)
            let (schedule, _, _) = Fixtures.twiceDailySchedule(itemID: item.id)
            try await store.save(schedule)
            items.append(item)
            schedules.append(schedule)
        }
        let before = Fixtures.instant("2026-03-01T00:00:00Z")
        try await store.generateOccurrences(at: before, deviceTimeZone: Fixtures.shanghai)
        var morning: [Occurrence] = []
        for schedule in schedules {
            morning.append(try #require(try await store.occurrence(slotID: schedule.slots[0].id, on: Fixtures.date(2026, 3, 1))))
        }
        // Iron is taken in the app, and Zinc is skipped. Copper is open.
        try await store.record(Fixtures.event(for: morning[0], .taken), scheduleVersionID: morning[0].scheduleVersionID)
        try await store.record(Fixtures.event(for: morning[1], .skipped), scheduleVersionID: morning[1].scheduleVersionID)
        let plan = ReminderPlan(items: items, schedules: schedules, now: before, deviceTimeZone: Fixtures.shanghai)
        let request = try #require(plan.requests.first { $0.trigger.time == Fixtures.time(8) })
        #expect(request.content.category == .group)
        let reminder = DeliveredReminder(deliveredAt: before, userInfo: request.userInfo, triggerWeekday: nil)

        let result = try await store.recordOpenDoses(
            for: reminder, action: .taken, at: Fixtures.instant("2026-03-01T00:10:00Z"),
            deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
        )

        #expect(result.named == 3 && result.recorded.count == 1 && result.unchangedCount == 2 && result.notRecordedCount == 0)
        #expect(try await store.status(of: morning[0].id) == .taken)
        #expect(try await store.status(of: morning[1].id) == .skipped)
        #expect(try await store.status(of: morning[2].id) == .taken)
        #expect(try await store.count("intakeEvent") == 3)
    }

    /// N1 (D089, D095): after an undo and a plan edit on the same day, an action records only into the dose of the plan of now.
    /// A follow-up that carries the old schedule version records nothing.
    @Test func takenActionAfterUndoAndAPlanEditRecordsOnlyTheNewPlan() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        try await store.record(Fixtures.event(for: seed.occurrence, .undo, supersedes: taken.id), scheduleVersionID: seed.versionID)
        // The user edits the dose on the same day. The new version is in force from today.
        var edited = seed.schedule
        let latest = try #require(edited.versions.last)
        try edited.appendVersion(
            ScheduleVersion(
                scheduleID: edited.id, effectiveFrom: Fixtures.date(2026, 3, 1), weeklyRule: latest.weeklyRule,
                slotTimes: latest.slotTimes, dose: try #require(Dose("2 capsules")), timeZonePolicy: latest.timeZonePolicy
            )
        )
        try await store.save(edited)
        let plan = ReminderPlan(
            items: [seed.item], schedules: [edited], now: Fixtures.instant("2026-03-01T00:00:00Z"), deviceTimeZone: Fixtures.shanghai
        )
        let request = try #require(plan.requests.first { $0.trigger.time == Fixtures.time(8) })
        let series = DeliveredReminder(
            deliveredAt: Fixtures.instant("2026-03-01T00:00:00Z"), userInfo: request.userInfo, triggerWeekday: nil
        )
        let followUp = DeliveredReminder(
            deliveredAt: Fixtures.instant("2026-03-01T00:15:00Z"),
            userInfo: [
                ReminderRequest.seriesIDKey: plan.series[0].id,
                FollowUpRequest.plannedDateKey: "2026-03-01",
                FollowUpRequest.itemIDKey: seed.item.id.rawValue.uuidString,
                // A follow-up takes the version of the stored occurrence, so it carries the old one.
                FollowUpRequest.scheduleVersionIDKey: seed.versionID.rawValue.uuidString,
            ],
            triggerWeekday: nil
        )
        // The undo left no record, so the open dose follows the new plan (D095). The follow-up of the old plan records
        // nothing, and the reminder of the new plan records the dose once.
        for (reminder, count) in [(followUp, 0), (series, 1)] {
            let result = try await store.recordOpenDoses(
                for: reminder, action: .taken, at: Fixtures.instant("2026-03-01T00:20:00Z"),
                deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
            )
            #expect(result.recorded.count == count)
        }
        #expect(try await store.count("intakeEvent") == 3)
    }

    @Test func sameEventIDWithOtherContentIsRejected() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        let changed = IntakeEvent(
            id: taken.id,
            occurrenceID: seed.occurrence.id,
            action: .skipped,
            occurredAt: taken.occurredAt,
            recordedAt: taken.recordedAt,
            source: .app
        )
        await #expect(throws: RecordFailure.rejected(.conflictingEvent)) {
            try await store.record(changed, scheduleVersionID: seed.versionID)
        }
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
    }

    @Test func eventTimesAreStoredExactly() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = IntakeEvent(
            occurrenceID: seed.occurrence.id,
            action: .taken,
            occurredAt: Date(timeIntervalSinceReferenceDate: 812_345_678.123_456_7),
            recordedAt: Date(),
            source: .notificationAction
        )
        try await store.record(taken, scheduleVersionID: seed.versionID)
        // A retry must compare equal to the stored event, so no time precision can be lost.
        #expect(try await store.history(of: seed.occurrence.id).events == [taken])
        try await store.record(taken, scheduleVersionID: seed.versionID)
    }

    // MARK: Spec 7.2: a record is on the storage medium when the call returns

    /// SQLite must sync the WAL file before a record call returns.
    /// With GRDB's WAL default, `synchronous = NORMAL`, a commit makes no sync call.
    @Test func recordIsSyncedBeforeTheCallReturns() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        try await store.writer.writeWithoutTransaction { try SyncProbe.attach(to: $0) }
        try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.versionID)
        let syncs = try await store.writer.writeWithoutTransaction { try SyncProbe.detach(from: $0) }
        #expect(!syncs.isEmpty)
        // `SQLITE_SYNC_FULL` is the sync of `fullfsync`. `SQLITE_SYNC_NORMAL` is `fsync`.
        #expect(syncs.allSatisfy { $0 & 0x0F == SQLITE_SYNC_FULL })
    }

    /// The transaction commits, `F_FULLFSYNC` fails with an input/output error, and `fsync` on the same file works.
    /// `fsync` does not wait for the drive, so the record call must give no success.
    @Test func recordWithAFailedFullFlushIsNotReportedAsRecordedWhenFsyncWorks() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let fsyncResults = OSAllocatedUnfairLock<[Int32]>(initialState: [])

        await #expect(throws: RecordFailure.storage(.unavailable)) {
            try await store.record(taken, scheduleVersionID: seed.versionID) { descriptor in
                let result = fsync(descriptor)
                fsyncResults.withLock { $0.append(result) }
                errno = EIO
                return -1
            }
        }
        // The store asked for one full flush, and `fsync` works on the file that it gave.
        #expect(fsyncResults.withLock { $0 } == [0])
        // The transaction did commit, so the caller must send the same event again.
        #expect(try await store.count("intakeEvent") == 1)

        // The same event again writes nothing, flushes, and gives the record.
        let record = try await store.record(taken, scheduleVersionID: seed.versionID)
        #expect(record.events == [taken])
        #expect(try await store.count("intakeEvent") == 1)
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
    }

    // MARK: T19: a failed write gives no success and leaves no partial data

    @Test func fullDiskLeavesNoEventAndNoState() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        // The database cannot grow, and the trigger needs many new pages when the projection is written.
        // So the event insert succeeds, and then SQLite reports "database or disk is full" in the same transaction.
        try await store.execute("CREATE TABLE filler (data BLOB)")
        try await store.execute(
            "CREATE TRIGGER fill AFTER INSERT ON occurrenceState BEGIN INSERT INTO filler VALUES (zeroblob(4000000)); END"
        )
        try await store.writer.writeWithoutTransaction { db in
            let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count")!
            _ = try Int.fetchOne(db, sql: "PRAGMA max_page_count = \(pageCount)")
        }
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        await #expect(throws: RecordFailure.storage(.diskFull)) {
            try await store.record(taken, scheduleVersionID: seed.versionID)
        }
        #expect(try await store.count("intakeEvent") == 0)
        try await store.expectConsistent(seed.occurrence, events: [], status: .unrecorded)

        // The occurrence is still pending, and the same event works when the disk has space again.
        try await store.writer.writeWithoutTransaction { db in
            _ = try Int.fetchOne(db, sql: "PRAGMA max_page_count = 1073741823")
        }
        let record = try await store.record(taken, scheduleVersionID: seed.versionID)
        #expect(record.status == .taken)
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
    }

    // MARK: T20: undo and correction

    @Test func undoReturnsToUnrecordedAndKeepsTheHistory() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let undo = Fixtures.event(for: seed.occurrence, .undo, supersedes: taken.id)
        let evening = Fixtures.occurrence(slotID: seed.evening, in: seed.schedule)
        try await store.save(evening)
        let eveningTaken = Fixtures.event(for: evening, .taken)
        try await store.record(eveningTaken, scheduleVersionID: seed.versionID)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        let record = try await store.record(undo, scheduleVersionID: seed.versionID)
        #expect(record.status == .unrecorded)
        try await store.expectConsistent(seed.occurrence, events: [taken, undo], status: .unrecorded)
        // The undo removes the state of its own occurrence only.
        try await store.expectConsistent(evening, events: [eveningTaken], status: .taken)
    }

    // MARK: D021: record a whole slot

    @Test func wholeSlotIsOneTransactionWithOneEventPerOpenItem() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        // Two more items in the same slot. The third one already has a record.
        var occurrences = [seed.occurrence]
        for name in ["Zinc", "Iron"] {
            let item = try Item(category: .supplement, name: name, form: .tablet, color: .blue)
            try await store.save(item)
            let (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: item.id)
            try await store.save(schedule)
            let occurrence = Fixtures.occurrence(slotID: morning, in: schedule)
            try await store.save(occurrence)
            occurrences.append(occurrence)
        }
        let recorded = occurrences[2]
        let earlier = Fixtures.event(for: recorded, .skipped)
        try await store.record(earlier, scheduleVersionID: recorded.scheduleVersionID)
        let open = occurrences[0...1].map { (event: Fixtures.event(for: $0, .taken), scheduleVersionID: $0.scheduleVersionID) }

        // A list with a rejected event writes none of its events.
        let withRecorded = open + [(Fixtures.event(for: recorded, .taken), recorded.scheduleVersionID)]
        await #expect(throws: RecordFailure.rejected(.alreadyRecorded)) { try await store.record(withRecorded) }
        #expect(try await store.count("intakeEvent") == 1)

        // The open items get one event each, also when the same list comes again.
        try await store.record(open)
        try await store.record(open)
        for (event, _) in open {
            let occurrence = try #require(occurrences.first { $0.id == event.occurrenceID })
            try await store.expectConsistent(occurrence, events: [event], status: .taken)
        }
        try await store.expectConsistent(recorded, events: [earlier], status: .skipped)
    }

    @Test func correctionReplacesTheValidStateAndKeepsTheLink() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let skipped = Fixtures.event(for: seed.occurrence, .skipped, supersedes: taken.id)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        try await store.record(skipped, scheduleVersionID: seed.versionID)
        #expect(try await store.history(of: seed.occurrence.id).events.last?.supersedes == taken.id)
        try await store.expectConsistent(seed.occurrence, events: [taken, skipped], status: .skipped)
    }

    @Test func recordAfterUndoLeavesOneValidIntake() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let undo = Fixtures.event(for: seed.occurrence, .undo, supersedes: taken.id)
        let takenAgain = Fixtures.event(for: seed.occurrence, .taken, supersedes: undo.id)
        for event in [taken, undo, takenAgain] {
            try await store.record(event, scheduleVersionID: seed.versionID)
        }
        // Two taken events exist in the history. Only the last one is valid.
        #expect(try await store.count("occurrenceState") == 1)
        try await store.expectConsistent(seed.occurrence, events: [taken, undo, takenAgain], status: .taken)
        // A new first event is still rejected after an undo.
        await #expect(throws: RecordFailure.rejected(.alreadyRecorded)) {
            try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.versionID)
        }
    }

    @Test func staleRevisionAndEmptyUndoChangeNothing() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        await #expect(throws: RecordFailure.rejected(.nothingToUndo)) {
            try await store.record(Fixtures.event(for: seed.occurrence, .undo), scheduleVersionID: seed.versionID)
        }
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        let skipped = Fixtures.event(for: seed.occurrence, .skipped, supersedes: taken.id)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        try await store.record(skipped, scheduleVersionID: seed.versionID)
        await #expect(throws: RecordFailure.rejected(.staleRevision)) {
            try await store.record(
                Fixtures.event(for: seed.occurrence, .undo, supersedes: taken.id),
                scheduleVersionID: seed.versionID
            )
        }
        try await store.expectConsistent(seed.occurrence, events: [taken, skipped], status: .skipped)
    }

    @Test func occurrencesKeepSeparateStates() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let tomorrow = Fixtures.occurrence(slotID: seed.morning, on: Fixtures.date(2026, 3, 2), in: seed.schedule)
        try await store.save(tomorrow)
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
        try await store.expectConsistent(tomorrow, events: [], status: .unrecorded)
    }

    // MARK: T20: the projection and the history must agree

    /// Ways to make the projection disagree with the history, from outside the store.
    enum Disagreement: CaseIterable {
        /// The status is not the action of the current event. The foreign key stops this write,
        /// so the test turns the foreign keys off, as damage or a write from other code can.
        case otherStatus
        /// The projection names an event that a correction replaced.
        case replacedEvent
        /// The projection has no row, and the history has a valid state.
        case missingRow
        /// The projection has a row, and the history ends with an undo.
        case rowAfterUndo
    }

    @Test(arguments: Disagreement.allCases)
    func disagreementIsReportedAndNotRepaired(_ disagreement: Disagreement) async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        var events = [taken]
        try await store.record(taken, scheduleVersionID: seed.versionID)
        switch disagreement {
        case .otherStatus:
            try await store.execute(
                "PRAGMA foreign_keys = OFF; UPDATE occurrenceState SET status = 'skipped'; PRAGMA foreign_keys = ON"
            )
        case .replacedEvent:
            events.append(Fixtures.event(for: seed.occurrence, .skipped, supersedes: taken.id))
            try await store.record(events[1], scheduleVersionID: seed.versionID)
            try await store.execute(
                "UPDATE occurrenceState SET eventID = ?, status = 'taken'",
                [taken.id.rawValue.uuidString]
            )
        case .missingRow:
            try await store.execute("DELETE FROM occurrenceState")
        case .rowAfterUndo:
            events.append(Fixtures.event(for: seed.occurrence, .undo, supersedes: taken.id))
            try await store.execute("CREATE TABLE kept AS SELECT * FROM occurrenceState")
            try await store.record(events[1], scheduleVersionID: seed.versionID)
            try await store.execute("INSERT INTO occurrenceState SELECT * FROM kept; DROP TABLE kept")
        }
        let last = try #require(events.last)
        let state = try await store.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM occurrenceState").map { row in
                [row["occurrenceID"] as String, row["eventID"] as String, row["status"] as String]
            }
        }

        // The read reports the disagreement. It does not return one of the two states.
        await #expect(throws: StorageError.invalidData) { try await store.status(of: seed.occurrence.id) }
        // The record transaction does not return success: not for the same event again, and not for a new event.
        let next = [
            last,
            Fixtures.event(for: seed.occurrence, .taken, supersedes: last.id),
            Fixtures.event(for: seed.occurrence, .skipped, supersedes: last.id),
            Fixtures.event(for: seed.occurrence, .undo, supersedes: last.id),
        ]
        for event in next {
            await #expect(throws: RecordFailure.storage(.invalidData)) {
                try await store.record(event, scheduleVersionID: seed.versionID)
            }
        }

        // Nothing changed. The history still loads, and the projection still has the rows it had.
        #expect(try await store.history(of: seed.occurrence.id).events == events)
        #expect(try await store.count("intakeEvent") == events.count)
        let stateAfter = try await store.writer.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM occurrenceState").map { row in
                [row["occurrenceID"] as String, row["eventID"] as String, row["status"] as String]
            }
        }
        #expect(stateAfter == state)
        #expect(try await store.writer.read { try Bool.fetchOne($0, sql: "PRAGMA foreign_keys") } == true)
    }
}
