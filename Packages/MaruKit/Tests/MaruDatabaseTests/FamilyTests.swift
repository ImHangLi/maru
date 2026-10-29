import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("Family (D121 to D126, T63, T69, T70)")
struct FamilyTests {
    let directory = TestDirectory()
    let folder = TestDirectory()

    /// A v7 upgrade keeps records and schedules, backfills every owner, and rolls back a failed migration (T37, T56).
    @Test func version7BackfillsMeWithoutChangingRecords() async throws {
        var version7 = DatabaseMigrator()
        for (name, sql) in [
            ("v1", Schema.v1), ("v2", Schema.v2), ("v3", Schema.v3), ("v4", Schema.v4),
            ("v5", Schema.v5), ("v6", Schema.v6), ("v7", Schema.v7),
        ] {
            version7.registerMigration(name) { db in try db.execute(sql: sql) }
        }
        let item = try Item(personID: PersonID(), category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        let archived = try Item(personID: PersonID(), category: .medication, name: "Old item", form: .tablet, color: .blue, isArchived: true)
        let (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: item.id)
        let occurrence = Fixtures.occurrence(slotID: morning, in: schedule)
        let event = Fixtures.event(for: occurrence, .taken)
        let file = folder.url.appendingPathComponent("Old.maru-backup")
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        do {
            let old = try LocalStore(directory: directory.url, migrator: version7)
            try await old.saveBeforeVersion6(item)
            try await old.saveBeforeVersion6(archived)
            try await old.save(schedule)
            try await old.save(occurrence)
            try await old.record(event, scheduleVersionID: occurrence.scheduleVersionID)
            try await old.backUp(to: file, settings: [:])
            try old.writer.close()
        }
        enum Failure: Error { case injected }
        var broken = version7
        broken.registerMigration("v8") { db in
            try db.execute(sql: Schema.v8)
            throw Failure.injected
        }
        #expect(throws: StorageError.migrationFailed) { try LocalStore(directory: directory.url, migrator: broken) }
        let queue = try DatabaseQueue(path: directory.databaseFile.path)
        #expect(try await queue.read { try !$0.tableExists("person") })
        #expect(try await queue.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM item") } == 2)
        try queue.close()

        let store = try LocalStore(directory: directory.url)
        #expect(try await store.people().map(\.kind) == [.me])
        let me = store.meID
        #expect(try await store.items().map(\.personID) == [me, me])
        #expect(try await store.item(id: archived.id)?.isArchived == true)
        #expect(try await store.schedule(id: schedule.id) == schedule)
        try await store.expectConsistent(occurrence, events: [event], status: .taken)
        _ = try await store.restore(try store.stage(backup: file))
        #expect(try await store.people().map(\.kind) == [.me])
        #expect(try await store.items().allSatisfy { $0.personID == store.meID })
        try await store.expectConsistent(occurrence, events: [event], status: .taken)
    }

    /// A backup of this version has its own "Me". The restore keeps exactly that one and does not seed a second (T69).
    @Test func aBackupWithMembersRestoresWithOneMe() async throws {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let event = Fixtures.event(for: seed.occurrence, .taken)
        try await store.record(event, scheduleVersionID: seed.versionID)
        let mochi = try Person(kind: .pet, name: "Mochi", symbol: .cat, color: .orange, imageReference: "mochi.jpg")
        try await store.save(mochi)
        var cat = try Item(personID: mochi.id, category: .medication, name: "Methimazole", form: .tablet, color: .blue)
        try await store.save(cat)
        cat = try #require(try await store.item(id: cat.id))
        let file = folder.url.appendingPathComponent("Maru Backup." + BackupFormat.fileExtension)
        try await store.backUp(to: file, settings: [:])

        let other = TestDirectory()
        let target = try LocalStore(directory: other.url)
        _ = try await target.restore(try target.stage(backup: file))
        #expect(try await target.people() == store.people())
        #expect(try await target.people().filter { $0.kind == .me }.count == 1)
        #expect(Set(try await target.items().map(\.id)) == [seed.item.id, cat.id])
        #expect(try await target.item(id: cat.id)?.personID == mochi.id)
        try await target.expectConsistent(seed.occurrence, events: [event], status: .taken)
    }

    /// A quick action that was listed before an owner change records nothing for the new owner (D123, T70).
    @Test func anActionListedBeforeAnOwnerChangeRecordsNothing() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let mom = try Person(kind: .person, name: "Mom")
        try await store.save(mom)
        let listed = Fixtures.instant("2026-03-01T00:00:00Z")
        let plan = try await store.reminderPlan(at: listed.addingTimeInterval(-60), deviceTimeZone: Fixtures.shanghai, privacy: .showNames)
        let request = try #require(plan.requests.first { $0.trigger.time == Fixtures.time(8) })
        try await store.setOwner(mom.id, of: seed.item.id, at: listed.addingTimeInterval(-30))
        // The old pending request can arrive after the owner change. Its owner proof must still fail.
        let late = DeliveredReminder(
            deliveredAt: listed, userInfo: request.userInfo, triggerWeekday: request.trigger.weekday
        )
        let result = try await store.recordOpenDoses(
            for: late, action: .taken, at: listed.addingTimeInterval(30), deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
        )
        #expect(result.recorded.isEmpty)
        #expect(try await store.status(of: seed.occurrence.id) == .unrecorded)
        let taken = Fixtures.event(for: seed.occurrence, .taken)

        await #expect(throws: RecordFailure.ownerChanged) {
            try await store.record([(taken, seed.versionID)], listedAt: listed.addingTimeInterval(-60))
        }
        #expect(try await store.status(of: seed.occurrence.id) == .unrecorded)

        // Yesterday's follow-up must fail after an owner change just after midnight (T70).
        let midnight = Fixtures.instant("2026-03-01T16:30:00Z")
        let owned = try #require(try await store.item(id: seed.item.id))
        let evening = try #require(plan.requests.first { $0.trigger.time == Fixtures.time(20) })
        let followUp = DeliveredReminder(deliveredAt: midnight.addingTimeInterval(-1800), userInfo: [
            ReminderRequest.seriesIDKey: evening.userInfo[ReminderRequest.seriesIDKey]!,
            ReminderRequest.ownerChangedKey: try #require(ReminderRequest.ownerChangedText(of: [owned.ownerChangedAt])),
            FollowUpRequest.plannedDateKey: "2026-03-01",
            FollowUpRequest.membersKey: seed.evening.text + "=" + seed.versionID.text,
        ], triggerWeekday: nil)
        try await store.setOwner(store.meID, of: seed.item.id, at: midnight.addingTimeInterval(-60))
        let yesterday = try await store.recordOpenDoses(
            for: followUp, action: .taken, at: midnight, deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil
        )
        #expect(yesterday.named == 1)
        #expect(yesterday.recorded.isEmpty)

        // A list that was read after the change records for the new owner.
        _ = try await store.record([(taken, seed.versionID)], listedAt: midnight.addingTimeInterval(60))
        #expect(try await store.status(of: seed.occurrence.id) == .taken)
    }

    /// The last active member cannot be archived, and an archive and a restore move the items of the member with it (D125, T63).
    @Test func archivingAMemberArchivesItsItemsAndTheLastMemberStays() async throws {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let me = store.meID
        await #expect(throws: StorageError.conflict) { try await store.archive(person: me) }

        let mom = try Person(kind: .person, name: "Mom")
        try await store.save(mom)
        try await store.setOwner(mom.id, of: seed.item.id)
        try await store.archive(person: mom.id)
        #expect(try await store.item(id: seed.item.id)?.isArchived == true)
        try await store.restore(person: mom.id)
        #expect(try await store.item(id: seed.item.id)?.isArchived == false)
    }
}
