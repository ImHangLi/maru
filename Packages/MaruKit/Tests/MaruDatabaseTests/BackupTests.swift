import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

@Suite("Backup and restore (D040, T38, T39)")
struct BackupTests {
    let directory = TestDirectory()
    /// The folder of the backup file, as the Files app is for the user.
    let folder = TestDirectory()

    private var backupFile: URL {
        folder.url.appendingPathComponent("Maru Backup." + BackupFormat.fileExtension)
    }

    /// A store with a taken dose, an as-needed dose, and a backup of the two.
    private func storeWithABackup(migrator: DatabaseMigrator = Schema.migrator) async throws -> (store: LocalStore, seed: Seed) {
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let store = try LocalStore(directory: directory.url, migrator: migrator)
        let seed = try await store.seed()
        try await store.record(Fixtures.event(for: seed.occurrence, .taken), scheduleVersionID: seed.versionID)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: seed.item.id, at: now, in: Fixtures.shanghai)
        try await store.recordAsNeeded(
            IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app), occurrence: dose
        )
        try await store.backUp(to: backupFile, settings: ["appColor": "mint"])
        return (store, seed)
    }

    private func temporaryFiles(in directory: TestDirectory) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.url.path).filter { $0.hasPrefix(LocalStore.temporaryPrefix) }
    }

    @Test func aRestoreOnAnotherDeviceGivesTheSameDataAndReplacesWhatWasThere() async throws {
        let (store, seed) = try await storeWithABackup()
        let today = Fixtures.date(2026, 3, 3)
        let lines = try await store.exportedDoses(through: today, deviceTimeZone: Fixtures.shanghai)
        #expect(lines.filter { $0.status == .taken }.count == 2)
        #expect(lines.contains { $0.status == .unrecorded })
        // A record with a date after the device date is in the file too, for example after travel to the west.
        let west = try await store.exportedDoses(through: Fixtures.date(2026, 2, 28), deviceTimeZone: Fixtures.shanghai)
        #expect(west.filter { $0.status == .taken }.count == 2)

        // The other device has an item of its own. A restore replaces it and does not merge.
        let other = TestDirectory()
        let old = try LocalStore(directory: other.url)
        try await old.save(try Item(category: .medication, name: "Old", form: .tablet, color: .blue))
        let staged = try old.stage(backup: backupFile)
        #expect(staged.settings == ["appColor": "mint"])
        _ = try await old.restore(staged)

        // The store stays open, and its reads give the restored data.
        #expect(try await old.items() == [seed.item])
        #expect(try await old.schedule(id: seed.schedule.id) == seed.schedule)
        #expect(try await old.history(of: seed.occurrence.id) == store.history(of: seed.occurrence.id))
        #expect(try await old.exportedDoses(through: today, deviceTimeZone: Fixtures.shanghai) == lines)
        #expect(try temporaryFiles(in: other).isEmpty)
        // A new open reads the restored database, and it takes a new record.
        try old.writer.close()
        let reopened = try LocalStore(directory: other.url)
        let evening = Fixtures.occurrence(slotID: seed.evening, in: seed.schedule)
        try await reopened.save(evening)
        try await reopened.record(Fixtures.event(for: evening, .skipped), scheduleVersionID: seed.versionID)
        #expect(try await reopened.status(of: evening.id) == .skipped)
    }

    @Test func aWriteThatWasReadBeforeARestoreIsRefused() async throws {
        let (store, seed) = try await storeWithABackup()
        let history = try await store.history(of: seed.occurrence.id)
        let undo = Fixtures.event(for: seed.occurrence, .undo, supersedes: history.events.last?.id)
        var archived = try #require(try await store.item(id: seed.item.id))
        archived.isArchived = true
        // The backup has the same IDs, so the stale undo and the stale archive match the restored data.
        let restored = try await store.restore(try store.stage(backup: backupFile))

        await #expect(throws: RecordFailure.replaced) {
            try await store.record([(undo, seed.versionID)], generation: restored.generation - 1)
        }
        await #expect(throws: StorageError.replaced) {
            try await store.save(archived, generation: restored.generation - 1)
        }
        #expect(try await store.history(of: seed.occurrence.id) == history)
        #expect(try await store.items() == [seed.item])
        try await store.record([(undo, seed.versionID)], generation: restored.generation)
        #expect(try await store.status(of: seed.occurrence.id) == .unrecorded)
    }

    @Test func aDamagedOrNewerBackupIsRefusedAndTheDataStays() async throws {
        var newer = Schema.migrator
        newer.registerMigration("v7") { db in
            try db.execute(sql: "CREATE TABLE extra (id TEXT)")
        }
        // The backup comes from a newer version of the app.
        _ = try await storeWithABackup(migrator: newer)
        let other = TestDirectory()
        let store = try LocalStore(directory: other.url)
        let seed = try await store.seed()
        #expect(throws: StorageError.newerSchema) { try store.stage(backup: backupFile) }

        // A file that is not a database, and a database that is not a backup.
        let notABackup = folder.url.appendingPathComponent("other")
        try Data("not a database".utf8).write(to: notABackup)
        #expect(throws: StorageError.corrupt) { try store.stage(backup: notABackup) }
        #expect(throws: StorageError.corrupt) { try store.stage(backup: other.databaseFile) }

        // A backup with a projection that disagrees with the events.
        let third = TestDirectory()
        let source = try LocalStore(directory: third.url)
        let record = try await source.seed()
        try await source.record(Fixtures.event(for: record.occurrence, .taken), scheduleVersionID: record.versionID)
        let broken = folder.url.appendingPathComponent("broken")
        try await source.backUp(to: broken, settings: [:])
        let file = try DatabaseQueue(path: broken.path)
        try await file.write { db in
            try db.execute(sql: "DELETE FROM occurrenceState")
        }
        try file.close()
        #expect(throws: StorageError.invalidData) { try store.stage(backup: broken) }

        #expect(try temporaryFiles(in: other).isEmpty)
        #expect(try await store.items() == [seed.item])
        #expect(try await store.schedule(id: seed.schedule.id) == seed.schedule)
    }

    /// A backup with a number of days that a cycle cannot have is refused before the restore, so no due date
    /// calculation meets a number that overflows (D065). The file has no check of its own: a file from
    /// another source can have any value.
    @Test func aBackupWithACycleOutsideTheLimitsIsRefusedAndTheDataStays() async throws {
        #expect(throws: ScheduleError.invalidDayCycle) {
            try DayCycle(start: Fixtures.date(2026, 3, 1), daysOn: .max, daysOff: 1)
        }
        let (store, seed) = try await storeWithABackup()
        let file = try DatabaseQueue(path: backupFile.path)
        try await file.writeWithoutTransaction { db in
            try db.execute(
                sql: """
                    PRAGMA ignore_check_constraints = ON;
                    UPDATE scheduleVersion SET cycleStart = '2026-03-01', cycleDaysOn = 9223372036854775807, cycleDaysOff = 1
                    """
            )
        }
        try file.close()
        #expect(throws: StorageError.self) { try store.stage(backup: backupFile) }
        #expect(try temporaryFiles(in: directory).isEmpty)
        #expect(try await store.schedule(id: seed.schedule.id) == seed.schedule)
    }

    /// A staged file that is gone must not restore as an empty database. The data stays, and the epoch of the
    /// widgets does not stay open (D048).
    @Test func aRestoreWithAMissingStagedFileChangesNothing() async throws {
        let (store, seed) = try await storeWithABackup()
        let staged = try store.stage(backup: backupFile)
        for file in LocalStore.files(of: staged.file) { try? FileManager.default.removeItem(at: file) }
        await #expect(throws: StorageError.self) { try await store.restore(staged) }
        #expect(try await store.items() == [seed.item])
        #expect(try await store.records(of: [seed.occurrence.id])[seed.occurrence.id]?.status == .taken)
        #expect(LocalStore.restoreEpoch(in: directory.url)! % 2 == 0)
    }
}
