import Foundation
import GRDB
import MaruCore

/// The backup file (D040). `docs/export-format.md` describes the format. Keep the two the same.
///
/// A backup is one SQLite database file: a consistent copy of the database of the store, with a mark
/// in the file header and one more table for the settings of the app.
public enum BackupFormat {
    public static let fileExtension = "marubackup"
    /// `PRAGMA application_id` of a backup file: the ASCII codes of "Maru".
    static let applicationID: Int32 = 0x4D61_7275
    /// `PRAGMA user_version` of a backup file. Raise it when a change makes an older app read a backup wrong.
    static let version: Int32 = 1
    static let settingsTable = """
        CREATE TABLE backupSetting (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL) STRICT
        """
}

/// A backup that passed every check and waits for the user to confirm the restore. See `LocalStore.stage`.
public struct StagedBackup: Sendable {
    /// The checked database, under a temporary name in the directory of the store.
    let file: URL
    /// The settings that the backup carries. The store keeps them as text and does not read them.
    public let settings: [String: String]
}

/// A restore that replaced the data. See `LocalStore.restore(_:)`.
public struct RestoreResult: Sendable {
    /// The generation of the restored data. Pass it with each write that the caller reads for from now on.
    public let generation: Int
    /// `false` when the storage medium did not confirm the commit. The data is replaced all the same.
    public let isFlushed: Bool
}

extension LocalStore {
    /// Writes a backup of the whole database to `file`, which must not exist (D040).
    ///
    /// `VACUUM INTO` reads the database in one read transaction, so the copy is consistent while the app
    /// writes. The copy is one file with no WAL file next to it. The file is not encrypted.
    /// A failure removes the file.
    public func backUp(to file: URL, settings: [String: String]) async throws(StorageError) {
        do {
            try await writer.writeWithoutTransaction { db in
                try db.execute(sql: "VACUUM INTO ?", arguments: [file.path])
            }
            try FileProtection.protect(files: [file], level: .complete)
            let copy = try DatabaseQueue(path: file.path)
            try await copy.writeWithoutTransaction { db in
                guard try String.fetchOne(db, sql: "PRAGMA journal_mode = DELETE") == "delete" else {
                    throw StorageError.unavailable
                }
                try db.inTransaction {
                    try db.execute(sql: BackupFormat.settingsTable)
                    for (key, value) in settings {
                        try db.execute(sql: "INSERT INTO backupSetting (key, value) VALUES (?, ?)", arguments: [key, value])
                    }
                    return .commit
                }
                try db.execute(
                    sql: "PRAGMA application_id = \(BackupFormat.applicationID); PRAGMA user_version = \(BackupFormat.version)"
                )
            }
            try copy.close()
        } catch {
            try? FileManager.default.removeItem(at: file)
            throw StorageError(error)
        }
    }

    /// Checks a backup file, and builds the database that a restore puts in place. The database of the store
    /// does not change (T38).
    ///
    /// The call does not trust the file. It builds a new database with the schema of this app, at the
    /// migration level of the backup, and copies each row into it under every constraint of that schema.
    /// Then it applies the later migrations and reads every item, schedule, occurrence, and record through
    /// the checks of a normal load. So a backup that restores is a database that the app can open and read.
    ///
    /// - `corrupt`: the file is not a backup of Maru, or it is damaged.
    /// - `newerSchema`: a newer version of the app made the backup.
    /// - `invalidData`: a stored value breaks a rule of the app.
    ///
    /// Call `restore(_:)` or `discard(_:)` with the result.
    public func stage(backup file: URL) throws(StorageError) -> StagedBackup {
        try stage(backup: file, migrator: Schema.migrator)
    }

    func stage(backup file: URL, migrator: DatabaseMigrator) throws(StorageError) -> StagedBackup {
        let staged = directory.appendingPathComponent(Self.temporaryPrefix + UUID().uuidString)
        let source = URL(fileURLWithPath: staged.path + "-source")
        do {
            try FileManager.default.copyItem(at: file, to: source)
            try FileProtection.protect(files: [source])
            let (level, settings) = try Self.describe(source, migrator: migrator)

            var configuration = Configuration()
            configuration.foreignKeysEnabled = true
            let pool = try DatabasePool(path: staged.path, configuration: configuration)
            try FileProtection.protect(files: Self.files(of: staged))
            try migrator.migrate(pool, upTo: level)
            try pool.writeWithoutTransaction { db in
                try db.execute(sql: "ATTACH DATABASE ? AS source", arguments: [source.path])
                try db.inTransaction {
                    // The foreign keys are checked at the commit, so the order of the tables does not matter.
                    try db.execute(sql: "PRAGMA defer_foreign_keys = ON")
                    let tables = try String.fetchAll(
                        db,
                        sql: """
                            SELECT name FROM main.sqlite_master
                            WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name <> 'grdb_migrations'
                            ORDER BY name
                            """
                    )
                    for table in tables {
                        // `rowid` keeps the order of the first save, which the reads of the store use.
                        let columns = try ["rowid"] + String.fetchAll(
                            db, sql: "SELECT name FROM pragma_table_info(?, 'main')", arguments: [table]
                        )
                        let list = columns.joined(separator: ", ")
                        try db.execute(sql: "INSERT INTO main.\(table) (\(list)) SELECT \(list) FROM source.\(table)")
                    }
                    return .commit
                }
                try db.execute(sql: "DETACH DATABASE source")
            }
            try migrator.migrate(pool)
            // A backup of version 1.0 holds the global follow-up setting. It moves to the staged items now, so the
            // restore replaces the data in one step and a failure here fails the restore before any change (D079).
            if let setting = Self.legacyFollowUp(in: settings) {
                try pool.write { db in try Self.adopt(setting, changed: nil, db) }
            }
            try pool.read(Self.validate)
            // Move every page to the database file, so the one file is the whole database.
            try pool.writeWithoutTransaction { db in
                _ = try db.checkpoint(.truncate)
            }
            try pool.close()
            guard Self.isEmpty(Self.files(of: staged)[1]) else { throw StorageError.unavailable }
            for file in Self.files(of: source) {
                try? FileManager.default.removeItem(at: file)
            }
            return StagedBackup(file: staged, settings: settings)
        } catch {
            Self.removeTemporaryFiles(in: directory)
            // SQLite or a constraint of the schema rejected the file or one of its rows.
            switch StorageError(error) {
            case .failed, .conflict: throw .corrupt
            case let error: throw error
            }
        }
    }

    /// The global "Remind Again" setting of a backup of version 1.0, or `nil` when it was off or the backup has none.
    /// Version 1.1 writes neither key, and its items carry their own setting (D079).
    static func legacyFollowUp(in settings: [String: String]) -> FollowUpSetting? {
        guard let interval = settings["remindAgainMinutes"].flatMap({ Int($0) }).flatMap(FollowUpInterval.init(rawValue:)) else {
            return nil
        }
        // A missing count means "1 Time", as for an install from before D039.
        let count = settings["remindAgainCount"].flatMap { Int($0) }.flatMap(FollowUpCount.init(rawValue:)) ?? .one
        return FollowUpSetting(count: count, interval: interval)
    }

    /// Reads what a backup file says about itself: the last migration that it has, and its settings.
    private static func describe(
        _ source: URL,
        migrator: DatabaseMigrator
    ) throws -> (level: String, settings: [String: String]) {
        let queue = try DatabaseQueue(path: source.path)
        defer { try? queue.close() }
        return try queue.read { db in
            guard try Int32.fetchOne(db, sql: "PRAGMA application_id") == BackupFormat.applicationID,
                  let version = try Int32.fetchOne(db, sql: "PRAGMA user_version"), version >= 1
            else { throw StorageError.corrupt }
            let applied = try String.fetchSet(db, sql: "SELECT identifier FROM grdb_migrations")
            let known = migrator.migrations
            guard version <= BackupFormat.version, applied.isSubset(of: known) else { throw StorageError.newerSchema }
            // A backup has the migrations of one app version: the first ones, with no gap.
            let completed = known.prefix(while: applied.contains)
            guard let level = completed.last, completed.count == applied.count else { throw StorageError.corrupt }
            var settings: [String: String] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT key, value FROM backupSetting") {
                settings[try row.decode(forColumn: "key")] = try row.decode(forColumn: "value")
            }
            return (level, settings)
        }
    }

    /// Reads the whole database through the checks of a normal load (spec 7.3). A normal load reads only
    /// the rows that a page needs. A restore reads every row first, so no page finds a bad row later.
    private static func validate(_ db: Database) throws {
        guard try String.fetchAll(db, sql: "PRAGMA integrity_check") == ["ok"],
              try Row.fetchOne(db, sql: "PRAGMA foreign_key_check") == nil
        else { throw StorageError.corrupt }
        _ = try Row.fetchAll(db, sql: "SELECT * FROM item").map(decodeItem)
        for id in try String.fetchAll(db, sql: "SELECT id FROM schedule") {
            _ = try fetchSchedule(db, id: ScheduleID(text: id))
        }
        for row in try Row.fetchAll(db, sql: "SELECT * FROM occurrence") {
            let slotID: String? = try row.decode(forColumn: "slotID")
            let id = try slotID == nil ? decodeAsNeededOccurrence(row).id : decodeOccurrence(row).id
            _ = try fetchCheckedRecord(db, occurrenceID: id)
        }
    }

    /// Removes a staged backup that the user did not confirm.
    public func discard(_ backup: StagedBackup) {
        for file in Self.files(of: backup.file) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Replaces every row of the database of the store with the rows of a staged backup (D040).
    ///
    /// The user asks for this and confirms it. It is not a recovery from an error (spec 7.3), and it does
    /// not merge: every item and record of the old database goes. The call removes the staged files,
    /// also after an error.
    ///
    /// The SQLite online backup copies the staged database into the open database in one write transaction.
    /// No file changes its name, and the store stays open. A stop of the app or an error before the commit
    /// rolls the transaction back, so the database has the complete old data or the complete new data.
    /// The barrier waits for each read and write that runs, and holds back each new one until the commit.
    ///
    /// The call throws only when the old data is in place. After the commit it returns, also when the flush
    /// to the storage medium fails, and the generation of the data goes up by one. From then on, a write with
    /// an older generation is refused (see `checkedWrite`). This is the one write that changes the generation.
    public func restore(_ backup: StagedBackup) async throws(StorageError) -> RestoreResult {
        defer { discard(backup) }
        let before = generation.withLock { $0 }
        // The epoch is odd while the restore can change the data, so no widget action or read works across it (D048).
        var epochIsOpen = false
        defer { if epochIsOpen { try? bumpEpoch() } }
        do {
            // The staged file must be there and must hold a database. SQLite creates a missing file as an empty
            // database, and the copy would then replace the data with nothing. So the source opens read-only.
            guard !Self.isEmpty(backup.file) else { throw StorageError.unavailable }
            var sourceConfiguration = Configuration()
            sourceConfiguration.readonly = true
            let staged = try DatabaseQueue(path: backup.file.path, configuration: sourceConfiguration)
            defer { try? staged.close() }
            try bumpEpoch()
            epochIsOpen = true
            try await writer.barrierWriteWithoutTransaction { db in
                try staged.read { source in
                    try source.backup(to: db)
                    // The commit replaced the data.
                    generation.withLock { $0 += 1 }
                }
            }
        } catch {
            let after = generation.withLock { $0 }
            // An error after the commit does not bring the old data back.
            guard after != before else { throw StorageError(error) }
            return RestoreResult(generation: after, isFlushed: false)
        }
        // The commit synced the WAL file to the drive. Wait until the drive wrote it to the storage medium.
        return RestoreResult(generation: generation.withLock { $0 }, isFlushed: Self.flush(walFile))
    }

    /// No file, or a file with no content.
    private static func isEmpty(_ file: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: file.path) else { return true }
        return (try? FileManager.default.attributesOfItem(atPath: file.path)[.size] as? Int) == 0
    }
}
