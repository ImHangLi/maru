import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("Migration failure and corruption (spec 7.3, T37)")
struct RecoveryTests {
    let directory = TestDirectory()

    private struct InjectedFailure: Error {}

    /// The app migrations plus one more migration, as a later app version has.
    private func migrator(adding identifier: String, _ migrate: @escaping @Sendable (Database) throws -> Void) -> DatabaseMigrator {
        var migrator = Schema.migrator
        migrator.registerMigration(identifier, migrate: migrate)
        return migrator
    }

    /// Stores an item and a taken record, moves them from the WAL file to the database file, and closes the database.
    private func storeARecord() async throws -> (seed: Seed, taken: IntakeEvent) {
        let store = try LocalStore(directory: directory.url)
        let seed = try await store.seed()
        let taken = Fixtures.event(for: seed.occurrence, .taken)
        try await store.record(taken, scheduleVersionID: seed.versionID)
        try await store.writer.writeWithoutTransaction { db in
            _ = try db.checkpoint(.truncate)
        }
        try store.writer.close()
        return (seed, taken)
    }

    private func fileNames() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.url.path))
    }

    private var storeFileNames: Set<String> {
        [LocalStore.fileName, LocalStore.fileName + "-wal", LocalStore.fileName + "-shm"]
    }

    /// What a first launch leaves when it stops before the database gets its final name:
    /// a database with a part of a schema under a temporary name, and the files that SQLite keeps next to it.
    private func leaveAnInterruptedFirstLaunch() throws -> Set<String> {
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        let name = LocalStore.temporaryPrefix + UUID().uuidString
        let pool = try DatabasePool(path: directory.url.appendingPathComponent(name).path)
        try pool.write { db in
            try db.execute(sql: "CREATE TABLE item (partial TEXT)")
        }
        try pool.close()
        let left = try fileNames().filter { $0.hasPrefix(LocalStore.temporaryPrefix) }
        #expect(left.count == 3)
        return left
    }

    @Test func migratorNeverErasesTheDatabase() {
        #expect(!Schema.migrator.eraseDatabaseOnSchemaChange)
        #expect(Schema.migrator.migrations == ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"])
    }

    @Test func failedMigrationReturnsATypedErrorAndKeepsTheData() async throws {
        let (seed, taken) = try await storeARecord()
        // The migration changes and deletes data, and then fails.
        let broken = migrator(adding: "v9") { db in
            try db.execute(sql: "CREATE TABLE extra (id TEXT)")
            try db.execute(sql: "DELETE FROM occurrenceState")
            try db.execute(sql: "UPDATE item SET name = 'changed'")
            throw InjectedFailure()
        }
        #expect(throws: StorageError.migrationFailed) {
            try LocalStore(directory: directory.url, migrator: broken)
        }
        #expect(try fileNames().contains(LocalStore.fileName))

        // The database is at the last migration of the app with all its data. It is not empty and not rebuilt.
        let store = try LocalStore(directory: directory.url)
        #expect(try await store.items() == [seed.item])
        #expect(try await store.schedule(id: seed.schedule.id) == seed.schedule)
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
        let (applied, hasExtraTable) = try await store.writer.read { db in
            (try Schema.migrator.appliedMigrations(db), try db.tableExists("extra"))
        }
        #expect(applied == ["v1", "v2", "v3", "v4", "v5", "v6", "v7", "v8"])
        #expect(!hasExtraTable)
    }

    /// A database of version 5 has no follow-up and no alarm on its items after `v6`. The global follow-up setting
    /// of version 1.0 then moves to every item that has none, one time (D079).
    @Test func version5ItemsGetTheGlobalFollowUpSettingAfterTheReminderOptionsMigration() async throws {
        var version5 = DatabaseMigrator()
        for (name, sql) in [("v1", Schema.v1), ("v2", Schema.v2), ("v3", Schema.v3), ("v4", Schema.v4), ("v5", Schema.v5)] {
            version5.registerMigration(name) { db in try db.execute(sql: sql) }
        }
        do {
            let store = try LocalStore(directory: directory.url, migrator: version5)
            for name in ["Zinc", "Iron"] {
                try await store.execute(
                    "INSERT INTO item (id, category, name, isArchived) VALUES (?, 'supplement', ?, 0)", [ItemID().text, name]
                )
            }
            try store.writer.close()
        }

        let store = try LocalStore(directory: directory.url)
        #expect(try await store.items().allSatisfy { $0.followUp == nil && !$0.alarm })
        var iron = try await store.items()[1]
        let own = FollowUpSetting(count: .five, interval: .minutes10)
        iron.followUp = own
        try await store.save(iron)

        let global = FollowUpSetting(count: .untilRecorded, interval: .minutes15)
        try store.adoptFollowUpSetting(global)
        #expect(try await store.items().map(\.followUp) == [global, own])
    }

    /// A database of version 1 keeps every item and record after `v2`. The items get the form `unknown`
    /// and the color `pink` (issue #20, D021).
    @Test func version1ItemsAndRecordsStayAfterTheFormAndColorMigration() async throws {
        var version1 = DatabaseMigrator()
        version1.registerMigration("v1") { db in
            try db.execute(sql: Schema.v1)
        }
        let vitaminD = try Item(personID: PersonID(), category: .supplement, name: "Vitamin D", form: .unknown, color: .pink)
        let fishOil = try Item(
            personID: PersonID(), category: .unknown, name: "Fish oil", form: .unknown, color: .pink, isArchived: true,
            intakeNote: .preset(.withFood)
        )
        let (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: vitaminD.id)
        let occurrence = Fixtures.occurrence(slotID: morning, in: schedule)
        let taken = Fixtures.event(for: occurrence, .taken)
        do {
            let store = try LocalStore(directory: directory.url, migrator: version1)
            // The item table of version 1 has no form and no color, so `save` cannot write to it.
            try await store.execute(
                "INSERT INTO item (id, category, name, isArchived) VALUES (?, 'supplement', 'Vitamin D', 0)",
                [vitaminD.id.text]
            )
            try await store.execute(
                """
                INSERT INTO item (id, category, name, isArchived, intakeNotePreset)
                VALUES (?, 'unknown', 'Fish oil', 1, 'withFood')
                """,
                [fishOil.id.text]
            )
            try await store.saveBeforeVersion4(schedule)
            try await store.save(occurrence)
            try await store.record(taken, scheduleVersionID: occurrence.scheduleVersionID)
            try store.writer.close()
        }

        // `v8` gives every old item to the one member "Me", and it keeps the rest of the item (D126, T56).
        let store = try LocalStore(directory: directory.url)
        let me = store.meID
        #expect(try await store.people().map(\.kind) == [.me])
        #expect(try await store.items() == [vitaminD, fishOil].map { var owned = $0; owned.personID = me; return owned })
        #expect(try await store.schedule(id: schedule.id) == schedule)
        try await store.expectConsistent(occurrence, events: [taken], status: .taken)
    }

    /// A database of version 2 keeps every occurrence, record, and occurrence order after `v3`,
    /// and then takes an as-needed dose (issue #22, D021).
    @Test func version2RecordsStayAfterTheAsNeededMigration() async throws {
        var version2 = DatabaseMigrator()
        version2.registerMigration("v1") { db in
            try db.execute(sql: Schema.v1)
        }
        version2.registerMigration("v2") { db in
            try db.execute(sql: Schema.v2)
        }
        let item = try Item(personID: PersonID(), category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        let (schedule, morning, evening) = Fixtures.twiceDailySchedule(itemID: item.id)
        let occurrences = [
            Fixtures.occurrence(slotID: evening, in: schedule),
            Fixtures.occurrence(slotID: morning, in: schedule),
        ]
        let taken = Fixtures.event(for: occurrences[1], .taken)
        do {
            let store = try LocalStore(directory: directory.url, migrator: version2)
            try await store.saveBeforeVersion6(item)
            try await store.saveBeforeVersion4(schedule)
            for occurrence in occurrences {
                // The insert of `save` names no item column, so it runs on version 2.
                try await store.save(occurrence)
            }
            try await store.record(taken, scheduleVersionID: occurrences[1].scheduleVersionID)
            try store.writer.close()
        }

        let store = try LocalStore(directory: directory.url)
        for occurrence in occurrences {
            #expect(try await store.occurrence(id: occurrence.id) == occurrence)
        }
        let order = try await store.writer.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM occurrence ORDER BY rowid")
        }
        #expect(order == occurrences.map(\.id.text))
        try await store.expectConsistent(occurrences[1], events: [taken], status: .taken)
        let dose = AsNeededOccurrence(itemID: item.id, at: Fixtures.instant("2026-03-01T04:00:00Z"), in: Fixtures.shanghai)
        let event = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: Date(), recordedAt: Date(), source: .app)
        try await store.recordAsNeeded(event, occurrence: dose)
        #expect(try await store.asNeededOccurrence(id: dose.id) == dose)
    }

    /// A database of version 3 keeps every schedule and record after `v4`, with the weekdays that it had,
    /// and then takes a schedule that repeats every second day (D036).
    @Test func version3SchedulesStayAfterTheEveryOtherDayMigration() async throws {
        var version3 = DatabaseMigrator()
        for (identifier, sql) in [("v1", Schema.v1), ("v2", Schema.v2), ("v3", Schema.v3)] {
            version3.registerMigration(identifier) { db in
                try db.execute(sql: sql)
            }
        }
        let item = try Item(personID: PersonID(), category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        var (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: item.id)
        let occurrence = Fixtures.occurrence(slotID: morning, in: schedule)
        let taken = Fixtures.event(for: occurrence, .taken)
        do {
            let store = try LocalStore(directory: directory.url, migrator: version3)
            try await store.saveBeforeVersion6(item)
            try await store.saveBeforeVersion4(schedule)
            try await store.save(occurrence)
            try await store.record(taken, scheduleVersionID: occurrence.scheduleVersionID)
            try store.writer.close()
        }

        let store = try LocalStore(directory: directory.url)
        #expect(try await store.schedule(id: schedule.id) == schedule)
        #expect(schedule.versions[0].dayCycle == nil)
        try await store.expectConsistent(occurrence, events: [taken], status: .taken)
        // An edit to every second day is a new version. It loads with its start date, and the old version stays.
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: Fixtures.date(2026, 3, 2),
                weeklyRule: .everyDay,
                dayCycle: DayCycle(start: Fixtures.date(2026, 3, 3), daysOn: 1, daysOff: 1),
                slotTimes: schedule.versions[0].slotTimes,
                timeZonePolicy: .fixed(Fixtures.shanghai)
            )
        )
        try await store.save(schedule)
        #expect(try await store.schedule(id: schedule.id) == schedule)
        // A start date with some weekdays only breaks the rule of the domain. The database rejects it.
        await #expect(throws: (any Error).self) {
            try await store.execute("UPDATE scheduleVersion SET weekdays = '135' WHERE cycleStart IS NOT NULL")
        }
    }

    /// A database of version 4 keeps a schedule of every second day after `v5`, as a cycle of 1 day and 1 day.
    /// Then it takes a cycle with a pause. A backup from version 4 restores with the same rule (D065, spec 7.3).
    @Test func version4EveryOtherDayStaysAfterTheDayCycleMigration() async throws {
        var version4 = DatabaseMigrator()
        for (identifier, sql) in [("v1", Schema.v1), ("v2", Schema.v2), ("v3", Schema.v3), ("v4", Schema.v4)] {
            version4.registerMigration(identifier) { db in
                try db.execute(sql: sql)
            }
        }
        let item = try Item(personID: PersonID(), category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        let schedule = Fixtures.twiceDailySchedule(itemID: item.id).schedule
        let folder = TestDirectory()
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let backup = folder.url.appendingPathComponent("Maru Backup." + BackupFormat.fileExtension)
        do {
            let store = try LocalStore(directory: directory.url, migrator: version4)
            try await store.saveBeforeVersion6(item)
            try await store.saveBeforeVersion4(schedule)
            try await store.execute("UPDATE scheduleVersion SET everyOtherDayFrom = '2026-03-03'")
            try await store.backUp(to: backup, settings: [:])
            try store.writer.close()
        }

        let store = try LocalStore(directory: directory.url)
        let everyOtherDay = try DayCycle(start: Fixtures.date(2026, 3, 3), daysOn: 1, daysOff: 1)
        var loaded = try #require(try await store.schedule(id: schedule.id))
        #expect(loaded.versions.map(\.dayCycle) == [everyOtherDay])
        #expect(loaded.versions[0].slotTimes == schedule.versions[0].slotTimes)
        try loaded.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: Fixtures.date(2026, 3, 10),
                weeklyRule: .everyDay,
                dayCycle: DayCycle(start: Fixtures.date(2026, 3, 10), daysOn: 21, daysOff: 7),
                slotTimes: schedule.versions[0].slotTimes,
                timeZonePolicy: .fixed(Fixtures.shanghai)
            )
        )
        try await store.save(loaded)
        #expect(try await store.schedule(id: schedule.id) == loaded)
        // The restore replaces the data, so the cycle with a pause goes, and the old rule is there again.
        _ = try await store.restore(try store.stage(backup: backup))
        #expect(try await store.schedule(id: schedule.id)?.versions.map(\.dayCycle) == [everyOtherDay])
        // A backup from before the Family restores with every item given to the one member "Me" (D126, T56).
        #expect(try await store.people().map(\.kind) == [.me])
        #expect(try await store.items().map(\.personID) == [store.meID])
    }

    // MARK: First launch

    /// A launch that stops right after the move can leave its temporary files next to the database.
    @Test func leftoverTemporaryFilesAreRemovedAndDoNotHideTheData() async throws {
        let (seed, taken) = try await storeARecord()
        _ = try leaveAnInterruptedFirstLaunch()
        let store = try LocalStore(directory: directory.url)
        // The store opened the database and did not start a first launch.
        #expect(try await store.items() == [seed.item])
        try await store.expectConsistent(seed.occurrence, events: [taken], status: .taken)
        #expect(try fileNames() == storeFileNames)
    }

    // MARK: Damage

    /// SQLite reads an empty file as a new database. The store must not (the review finding on T37).
    @Test(arguments: [true, false])
    func emptyDatabaseFileIsReportedAndLeftInPlace(keepsWALFiles: Bool) async throws {
        _ = try await storeARecord()
        if !keepsWALFiles {
            for name in storeFileNames.subtracting([LocalStore.fileName]) {
                try FileManager.default.removeItem(at: directory.url.appendingPathComponent(name))
            }
        }
        try FileHandle(forWritingTo: directory.databaseFile).truncate(atOffset: 0)
        let names = try fileNames()

        // A second try gives the same error. The store did not make a new, empty database.
        for _ in 0..<2 {
            #expect(throws: StorageError.corrupt) {
                try LocalStore(directory: directory.url)
            }
        }
        // SQLite did not write to the file: it has no schema and no tables, and no file is new.
        #expect(try Data(contentsOf: directory.databaseFile).isEmpty)
        #expect(try fileNames() == names)
    }

    @Test func missingDatabaseFileNextToItsWALFilesIsReported() async throws {
        _ = try await storeARecord()
        try FileManager.default.removeItem(at: directory.databaseFile)
        let names = try fileNames()
        #expect(names == storeFileNames.subtracting([LocalStore.fileName]))

        #expect(throws: StorageError.corrupt) {
            try LocalStore(directory: directory.url)
        }
        // The store did not start a first launch over the rest of the old database.
        #expect(try fileNames() == names)
    }

    @Test func damagedDatabaseIsReportedAndLeftInPlace() async throws {
        _ = try await storeARecord()
        // Keep the SQLite header, and damage every page after it.
        var bytes = try Data(contentsOf: directory.databaseFile)
        #expect(bytes.count > 8_192)
        for index in 100..<bytes.count {
            bytes[index] = UInt8(truncatingIfNeeded: index &* 31 &+ 7)
        }
        try bytes.write(to: directory.databaseFile)

        // The damage shows when the database opens or at the first read.
        await #expect(throws: StorageError.corrupt) {
            let store = try LocalStore(directory: directory.url)
            _ = try await store.items()
        }
        #expect(try Data(contentsOf: directory.databaseFile) == bytes)
    }

    @Test func databaseFromANewerAppIsReportedAndLeftInPlace() async throws {
        let newer = migrator(adding: "v9") { db in
            try db.execute(sql: "CREATE TABLE extra (id TEXT)")
        }
        let seed: Seed
        do {
            let store = try LocalStore(directory: directory.url, migrator: newer)
            seed = try await store.seed()
            try store.writer.close()
        }
        #expect(throws: StorageError.newerSchema) {
            try LocalStore(directory: directory.url)
        }
        let store = try LocalStore(directory: directory.url, migrator: newer)
        #expect(try await store.items() == [seed.item])
        #expect(try await store.writer.read { try $0.tableExists("extra") })
    }
}
