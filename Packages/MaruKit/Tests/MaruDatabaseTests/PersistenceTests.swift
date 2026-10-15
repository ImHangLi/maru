import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("Stored domain values and keys (spec 7.3, T17)")
struct PersistenceTests {
    let directory = TestDirectory()

    // MARK: Items

    @Test func itemIsStoredAndUpdated() async throws {
        let store = try LocalStore(directory: directory.url)
        var item = try Item(
            category: .medication, name: "Metformin", form: .tablet, color: .blue, intakeNote: .preset(.withFood)
        )
        let other = try Item(
            category: .unknown, name: "鱼油", form: .softgel, color: .orange
        )
        try await store.save(item)
        try await store.save(other)
        #expect(try await store.items() == [item, other])

        try item.rename("Metformin XR")
        item.isArchived = true
        item.form = .unknown
        item.color = .brown
        item.intakeNote = try .custom("After the evening walk")
        item.imageReference = "photo.png"
        try await store.save(item)
        #expect(try await store.item(id: item.id) == item)
        #expect(try await store.items() == [item, other])
        #expect(try await store.item(id: ItemID()) == nil)
    }

    /// "For all items" in Settings changes every active item that has a time, in one write, and no other item (D085).
    /// A changed "Remind Again" gets the time of the change, so the limit of 12 for one dose holds. An item that
    /// already has the value keeps its old change time.
    @Test func bulkReminderOptionsChangeOnlyActiveItemsWithATimeAndStampTheChange() async throws {
        let store = try LocalStore(directory: directory.url)
        let earlier = Fixtures.instant("2026-03-01T00:00:00Z")
        let now = Fixtures.instant("2026-03-02T00:00:00Z")
        let target = FollowUpSetting(count: .untilRecorded, interval: .minutes30)
        let off = try Item(category: .supplement, name: "Zinc", form: .capsule, color: .pink)
        let same = try Item(
            category: .supplement, name: "Iron", form: .capsule, color: .blue, followUp: target, followUpChanged: earlier
        )
        let other = try Item(
            category: .medication, name: "Metformin", form: .tablet, color: .green,
            followUp: FollowUpSetting(count: .five, interval: .minutes10), followUpChanged: earlier
        )
        // A migrated item whose old change was not confirmed keeps its marker, so the legacy removal check still runs (D079).
        let pending = try Item(
            category: .supplement, name: "Calcium", form: .tablet, color: .orange,
            followUp: FollowUpSetting(count: .two, interval: .minutes15), followUpChanged: .distantFuture
        )
        let archived = try Item(category: .supplement, name: "Old", form: .capsule, color: .brown, isArchived: true)
        let untimed = try Item(category: .supplement, name: "Arnica", form: .drop, color: .mint)
        for item in [off, same, other, pending, archived, untimed] { try await store.save(item) }
        for item in [off, same, other, pending, archived] {
            try await store.save(Fixtures.twiceDailySchedule(itemID: item.id).schedule)
        }

        #expect(try await store.timedItems().map(\.name) == ["Zinc", "Iron", "Metformin", "Calcium"])
        #expect(try await store.apply(.followUp(target), toTimedItemsAt: now) == 3)
        let items = try await store.items()
        #expect(items.map(\.followUp) == [target, target, target, target, nil, nil])
        #expect(items.map(\.followUpChanged) == [now, earlier, now, .distantFuture, nil, nil])

        // A new interval changes only the items that have "Remind Again" on, and the alarm changes every timed item.
        #expect(try await store.apply(.followUp(nil), toTimedItemsAt: now) == 4)
        #expect(try await store.apply(.followUpInterval(.minutes5), toTimedItemsAt: now) == 0)
        #expect(try await store.apply(.alarm(true), toTimedItemsAt: now) == 4)
        #expect(try await store.items().map(\.alarm) == [true, true, true, true, false, false])
        #expect(ReminderOptionsSummary(items: try await store.timedItems()).alarm == .same(true))
    }

    /// A delete removes one item with its schedule, its occurrences, and its events. Another item keeps
    /// every row, and its event history and projection still agree (D033).
    @Test func deleteRemovesOneItemWithItsRecordsAndLeavesAnotherItemUnchanged() async throws {
        let store = try LocalStore(directory: directory.url)
        let deleted = try await store.seed()
        let kept = try await store.seed()
        let taken = Fixtures.event(for: deleted.occurrence, .taken)
        try await store.record(taken, scheduleVersionID: deleted.versionID)
        try await store.record(
            Fixtures.event(for: deleted.occurrence, .skipped, supersedes: taken.id), scheduleVersionID: deleted.versionID
        )
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: deleted.item.id, at: now, in: Fixtures.shanghai)
        try await store.recordAsNeeded(
            IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app),
            occurrence: dose
        )
        let keptEvent = Fixtures.event(for: kept.occurrence, .taken)
        try await store.record(keptEvent, scheduleVersionID: kept.versionID)

        let result = try await store.deleteItem(deleted.item.id)
        #expect(result?.schedules == [deleted.schedule.id])
        #expect(result?.versions == [deleted.versionID])

        #expect(try await store.items() == [kept.item])
        #expect(try await store.schedule(id: kept.schedule.id) == kept.schedule)
        try await store.expectConsistent(kept.occurrence, events: [keptEvent], status: .taken)
        let rows = [
            "schedule": 1, "scheduleSlot": 2, "scheduleVersion": 1, "scheduleVersionSlot": 2,
            "occurrence": 1, "intakeEvent": 1, "occurrenceState": 1,
        ]
        for (table, count) in rows {
            #expect(try await store.count(table) == count, "\(table)")
        }
        // A second delete finds no item and changes nothing.
        #expect(try await store.deleteItem(deleted.item.id) == nil)
    }

    /// The edit screen saves an item and its schedule together (issue #8). A second tap on Save must not
    /// double the item, and a failed schedule must not leave a changed item behind.
    @Test func itemAndScheduleAreSavedInOneTransaction() async throws {
        let store = try LocalStore(directory: directory.url)
        var item = try Item(category: .supplement, name: "Zinc", form: .capsule, color: .pink)
        let (schedule, _, _) = Fixtures.twiceDailySchedule(itemID: item.id, dose: Dose("1000 IU"))
        try await store.save(item, schedule: schedule)
        try await store.save(item, schedule: schedule)
        #expect(try await store.items() == [item])
        #expect(try await store.schedules(of: item.id) == [schedule])

        // A schedule that does not extend the stored one is a conflict. The rename rolls back with it.
        let replaced = Schedule(id: schedule.id, itemID: item.id, isEnabled: true)
        try item.rename("Zinc picolinate")
        await #expect(throws: StorageError.conflict) { try await store.save(item, schedule: replaced) }
        #expect(try await store.item(id: item.id)?.name == "Zinc")
        #expect(try await store.schedules(of: item.id) == [schedule])
    }

    /// "Replace with a new product" adds a new item and archives the old one in one transaction (T06).
    /// A past record stays with the old item, so it still names the old product.
    @Test func replaceKeepsOldRecordsWithTheOldName() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        _ = try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.occurrence.scheduleVersionID)
        let new = try Item(category: .supplement, name: "Vitamin D3 2000 IU", form: .softgel, color: .pink)
        let (schedule, _, _) = Fixtures.twiceDailySchedule(itemID: new.id)

        try await store.replace(seed.item.id, with: new, schedule: schedule)
        try await store.replace(seed.item.id, with: new, schedule: schedule)

        var archived = seed.item
        archived.isArchived = true
        #expect(try await store.items() == [archived, new])
        #expect(try await store.schedules(of: seed.item.id) == [seed.schedule])
        #expect(try await store.schedules(of: new.id) == [schedule])
        #expect(try await store.records(of: [seed.occurrence.id])[seed.occurrence.id]?.events.count == 1)
        await #expect(throws: StorageError.conflict) { try await store.replace(ItemID(), with: new, schedule: nil) }
    }

    // MARK: Schedules

    @Test func scheduleIsStoredWithItsSlotsAndVersions() async throws {
        let store = try LocalStore(directory: directory.url)
        let item = try Item(category: .supplement, name: "Zinc", form: .capsule, color: .pink)
        try await store.save(item)
        // The dose keeps the exact text of the user. The database does not parse or convert it.
        var (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: item.id, dose: Dose(" 500 μg"))
        try await store.save(schedule)
        #expect(try await store.schedule(id: schedule.id) == schedule)

        // An edit appends a version. The slot IDs and the first version stay as they are.
        try schedule.changeTime(of: morning, to: Fixtures.time(7, 30), effectiveFrom: Fixtures.date(2026, 3, 1))
        schedule.isEnabled = false
        schedule.endDate = Fixtures.date(2026, 12, 31)
        try await store.save(schedule)
        try await store.save(schedule)
        let stored = try #require(try await store.schedule(id: schedule.id))
        #expect(stored == schedule)
        #expect(stored.versions.count == 2)
        #expect(stored.versions.first?.dose?.text == " 500 μg")
        #expect(try await store.schedules(of: item.id) == [schedule])
        #expect(try await store.schedule(id: ScheduleID()) == nil)
    }

    @Test func scheduleThatDoesNotLoadIsRejectedOnSave() async throws {
        let store = try LocalStore(directory: directory.url)
        let item = try Item(category: .supplement, name: "Zinc", form: .capsule, color: .pink)
        try await store.save(item)
        let (schedule, _, _) = Fixtures.twiceDailySchedule(itemID: item.id, dose: Dose("500 μg"))
        try await store.save(schedule)

        // A NUL character ends a text value in SQLite, so this dose loads as "500". The exact text is lost.
        func version(of scheduleID: ScheduleID, slotTimes: [SlotTime]) throws -> ScheduleVersion {
            try ScheduleVersion(
                scheduleID: scheduleID,
                effectiveFrom: Fixtures.date(2026, 3, 1),
                weeklyRule: .everyDay,
                slotTimes: slotTimes,
                dose: Dose("500\0 mg"),
                timeZonePolicy: .fixed(Fixtures.shanghai)
            )
        }
        var edited = schedule
        try edited.appendVersion(version(of: schedule.id, slotTimes: schedule.versions[0].slotTimes))
        var new = Schedule(itemID: item.id, isEnabled: true)
        let slot = try new.addSlot().id
        try new.appendVersion(version(of: new.id, slotTimes: [SlotTime(slotID: slot, time: Fixtures.time(9))]))
        for invalid in [edited, new] {
            await #expect(throws: StorageError.invalidData) { try await store.save(invalid) }
        }
        #expect(try await store.schedules(of: item.id) == [schedule])
        #expect(try await store.count("scheduleVersion") == 1)
        #expect(try await store.count("scheduleSlot") == 2)
    }

    // MARK: Occurrences (T17)

    @Test func occurrenceIsStoredOnceForEachSlotAndDate() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        try await store.save(seed.occurrence)
        #expect(try await store.occurrence(id: seed.occurrence.id) == seed.occurrence)
        #expect(try await store.occurrence(slotID: seed.morning, on: Fixtures.date(2026, 3, 1)) == seed.occurrence)
        #expect(try await store.occurrence(slotID: seed.morning, on: Fixtures.date(2026, 3, 2)) == nil)

        // A second occurrence with the same slot and plan date has a new ID, and the database rejects it.
        let duplicate = Fixtures.occurrence(slotID: seed.morning, in: seed.schedule)
        await #expect(throws: StorageError.conflict) { try await store.save(duplicate) }
        #expect(try await store.count("occurrence") == 1)

        // The same slot on the next day is another occurrence.
        let tomorrow = Fixtures.occurrence(slotID: seed.morning, on: Fixtures.date(2026, 3, 2), in: seed.schedule)
        try await store.save(tomorrow)
        #expect(try await store.count("occurrence") == 2)
    }

    /// The move of the database to the App Group container keeps every record and leaves the old files (D048, spec 7.3).
    @Test func adoptCopiesTheEarlierDatabaseOnceAndKeepsTheOldOne() async throws {
        let earlier = TestDirectory()
        let old = try LocalStore(directory: earlier.url)
        let seed = try await old.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        try await old.record(taken, scheduleVersionID: seed.versionID)
        try old.writer.close()

        try LocalStore.adopt(from: earlier.url, into: directory.url)
        let moved = try LocalStore(directory: directory.url)
        #expect(try await moved.items() == [seed.item])
        #expect(try await moved.records(of: [seed.occurrence.id])[seed.occurrence.id]?.status == .taken)
        try moved.writer.close()
        #expect(FileManager.default.fileExists(atPath: earlier.databaseFile.path))

        // A second call changes nothing, also when the earlier directory has other data.
        try LocalStore.adopt(from: earlier.url, into: directory.url)
        let again = try LocalStore(directory: directory.url)
        #expect(try await again.items() == [seed.item])
    }
}
