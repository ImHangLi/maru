import Foundation
import GRDB
import os

/// The on-device database of items, schedules, occurrences, and intake events.
///
/// All health data stays in this database on the device (spec 10). Preferences are not in it (spec 7.1).
public struct LocalStore: Sendable {
    static let fileName = "maru.sqlite"
    /// A first launch builds the database under this name with a UUID at the end. See `create`.
    static let temporaryPrefix = fileName + ".new-"
    /// One open at a time in the process. See `init`.
    static let opening = NSLock()

    /// The directory that holds the database file and the files that SQLite keeps next to it.
    let directory: URL
    let writer: DatabasePool
    /// The number of restores since the store opened. A write that a caller read for before a restore is refused.
    /// See `restore(_:)` and `checkedWrite`.
    let generation = OSAllocatedUnfairLock(initialState: 0)

    /// Opens the database in `directory`, and creates it when the directory has none.
    ///
    /// A failure is a typed error. The database files stay as they are: nothing is deleted, replaced, or rebuilt,
    /// and a failed open never gives an empty store (spec 7.3, T37). Only a restore that the user confirms
    /// replaces the data. See `restore(_:)`.
    public init(directory: URL) throws(StorageError) {
        try self.init(directory: directory, migrator: Schema.migrator)
    }

    init(directory: URL, migrator: DatabaseMigrator) throws(StorageError) {
        self.directory = directory
        let database = directory.appendingPathComponent(Self.fileName)
        // Two opens at the same time in one process must not both decide that this is a first launch,
        // and one must not remove the temporary files that the other one uses.
        Self.opening.lock()
        defer { Self.opening.unlock() }
        do {
            // Protect the directory first, so that every file SQLite creates in it starts protected.
            try FileProtection.prepare(directory: directory)
            if try Self.hasDatabase(in: directory) {
                // A launch that stopped right after the move can leave temporary files next to the database.
                Self.removeTemporaryFiles(in: directory)
            } else {
                try Self.create(database, migrator: migrator)
            }
        } catch {
            throw StorageError(error)
        }
        writer = try Self.open(database, migrator: migrator)
        // No restore runs in a process that has just opened its store, so an odd epoch is the rest of an interrupted restore (D089).
        Self.closeInterruptedRestoreEpoch(in: directory)
    }

    /// Tells a first launch from a database that lost its file or its content.
    ///
    /// SQLite reads a missing file and an empty file as a new database. `create` gives the file name only
    /// to a complete database, so here an empty file is damage. The check runs before SQLite opens the file,
    /// so the file stays as it is and the store never shows an empty list in place of lost data (spec 7.3, T37).
    ///
    /// `afterFirstLook` is for tests. It runs when the first look finds no database file.
    static func hasDatabase(in directory: URL, afterFirstLook: () throws -> Void = {}) throws -> Bool {
        let fileManager = FileManager.default
        let files = Self.files(in: directory)
        if !fileManager.fileExists(atPath: files[0].path) {
            try afterFirstLook()
            guard files.dropFirst().contains(where: { fileManager.fileExists(atPath: $0.path) }) else {
                return false
            }
            // WAL and SHM files with no database file are the rest of a database, not a first launch.
            // Another process can complete a first launch between the two looks, and then the database
            // file is there now. A database file gets its name before its WAL and SHM files exist,
            // and the store never removes it, so a second look tells the two cases apart.
            guard fileManager.fileExists(atPath: files[0].path) else { throw StorageError.corrupt }
        }
        let size = try fileManager.attributesOfItem(atPath: files[0].path)[.size] as? Int
        guard size != 0 else { throw StorageError.corrupt }
        return true
    }

    /// Creates the database of a first launch under a temporary name in the same protected directory,
    /// and gives it the final name after the migrations complete.
    ///
    /// A launch that stops before the move leaves no file with the final name, so the next launch is
    /// a first launch again. A temporary file of a first launch never holds user data, because no store exists
    /// before the move. A temporary file of a restore holds a copy of a backup file, and the backup file stays
    /// where the user keeps it (D040). So the temporary files are the only files that the store removes.
    private static func create(_ database: URL, migrator: DatabaseMigrator) throws(StorageError) {
        let directory = database.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(temporaryPrefix + UUID().uuidString)
        // Remove the temporary files of this launch and of earlier launches that stopped early.
        defer { removeTemporaryFiles(in: directory) }
        let pool = try open(temporary, migrator: migrator)
        do {
            // Move every page from the WAL file to the database file, so the one file is the whole database.
            try pool.writeWithoutTransaction { db in
                _ = try db.checkpoint(.truncate)
            }
            try pool.close()
        } catch {
            throw StorageError(error)
        }
        // The move is atomic and never replaces a file. If another launch moved its database first, open that one.
        guard renamex_np(temporary.path, database.path, UInt32(RENAME_EXCL)) == 0
            || FileManager.default.fileExists(atPath: database.path)
        else { throw .unavailable }
        // Put the new name and the database on the storage medium before a store exists. A record that
        // the store reports as written must not disappear with the name of its database after a power loss.
        guard flush(directory) else { throw .unavailable }
    }

    /// Waits until the storage medium has `file`, or the entries of a directory, and every earlier
    /// write that the drive got.
    ///
    /// `F_FULLFSYNC` is the only call on an Apple platform that waits for the drive to write its cache.
    /// The SQLite of the system does not make this call. See `makeDurable`.
    ///
    /// No other call replaces it. `fsync` sends the data to the drive and does not wait for the drive,
    /// so a failed `F_FULLFSYNC` is a failed flush for every error code, also when `fsync` works (spec 7.2).
    /// The store has no fallback for a volume without `F_FULLFSYNC`. An iPhone always has APFS, which supports it.
    ///
    /// `sync` is for tests. It gets the open file and returns the result of the `F_FULLFSYNC` call.
    static func flush(_ file: URL, sync: (Int32) -> Int32 = fullSync) -> Bool {
        let descriptor = Darwin.open(file.path, O_RDONLY)
        guard descriptor >= 0 else { return false }
        defer { close(descriptor) }
        return sync(descriptor) == 0
    }

    static let fullSync: @Sendable (Int32) -> Int32 = { fcntl($0, F_FULLFSYNC) }

    static func removeTemporaryFiles(in directory: URL) {
        let fileManager = FileManager.default
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasPrefix(temporaryPrefix) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    /// Opens the database file and applies the migrations.
    private static func open(_ file: URL, migrator: DatabaseMigrator) throws(StorageError) -> DatabasePool {
        let pool: DatabasePool
        do {
            var configuration = Configuration()
            configuration.foreignKeysEnabled = true
            // The app and the widgets open the same database (D048). A short wait replaces an instant failure.
            configuration.busyMode = .timeout(3)
            // A pool opens the database in WAL mode.
            pool = try DatabasePool(path: file.path, configuration: configuration)
            // A new file gets the level of the directory on a device. Set the level on each file too,
            // before the migrations write to it. A file from an earlier build can have another level (D066),
            // also the rollback journal of a migration and the epoch file, which a record of the widget reads.
            try FileProtection.protect(
                files: files(of: file) + [
                    URL(fileURLWithPath: file.path + "-journal"),
                    file.deletingLastPathComponent().appendingPathComponent(epochFileName),
                ]
            )
            try makeDurable(pool)
            guard try !pool.read(migrator.hasBeenSuperseded) else { throw StorageError.newerSchema }
        } catch {
            throw StorageError(error)
        }
        do {
            // A failed migration rolls back, so the database keeps the version and the data it had.
            try migrator.migrate(pool)
        } catch {
            switch StorageError(error) {
            case .corrupt: throw .corrupt
            case .diskFull: throw .diskFull
            case .unavailable: throw .unavailable
            default: throw .migrationFailed
            }
        }
        return pool
    }

    /// Makes the writer sync the WAL file at each commit, so a committed write is still there
    /// after a system crash (spec 7.2).
    ///
    /// GRDB sets `synchronous = NORMAL` when it puts the database in WAL mode. This level does not
    /// sync the WAL file at a commit. GRDB sets it after `Configuration.prepareDatabase` runs,
    /// so the store sets the level here, on the one writer connection that the pool keeps,
    /// before the migrations and before every write of the store.
    ///
    /// `synchronous = FULL` syncs the WAL file at each commit. `fullfsync` makes each sync stronger
    /// than `fsync`, also the syncs of a checkpoint, so `checkpoint_fullfsync` is not necessary.
    /// With the SQLite of the system, the stronger sync is `F_BARRIERFSYNC` and not `F_FULLFSYNC`.
    /// It makes the drive keep the order of the writes, which protects the database from damage
    /// after a power loss. It does not wait for the drive. The record transaction calls `flush` for that.
    private static func makeDurable(_ pool: DatabasePool) throws {
        try pool.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA synchronous = FULL; PRAGMA fullfsync = ON")
        }
    }

    /// The database file, and the WAL and SHM files that SQLite keeps next to it (spec 10).
    var files: [URL] { Self.files(in: directory) }

    /// The file that holds a commit until a checkpoint moves it to the database file.
    var walFile: URL { files[1] }

    private static func files(in directory: URL) -> [URL] {
        files(of: directory.appendingPathComponent(fileName))
    }

    static func files(of database: URL) -> [URL] {
        [database, URL(fileURLWithPath: database.path + "-wal"), URL(fileURLWithPath: database.path + "-shm")]
    }

    func read<T: Sendable>(_ value: @Sendable (Database) throws -> T) async throws(StorageError) -> T {
        do {
            return try await writer.read(value)
        } catch {
            throw StorageError(error)
        }
    }

    /// Runs `updates` in one transaction with the check of `checkedWrite`. An error rolls back every change that `updates` made.
    func write<T: Sendable>(generation: Int, _ updates: @Sendable (Database) throws -> T) async throws(StorageError) -> T {
        do {
            return try await checkedWrite(generation: generation, updates)
        } catch {
            throw StorageError(error)
        }
    }

    /// The one write transaction of the store, except the restore (D040).
    ///
    /// `generation` is the generation of the data that the caller read: 0, or the generation that the last
    /// `restore(_:)` gave. Another value throws `StorageError.replaced` before any change. The restore runs on
    /// the same writer, so the check and the write are in order with it: no value of the old data goes into
    /// the restored data.
    func checkedWrite<T: Sendable>(generation: Int, _ updates: @Sendable (Database) throws -> T) async throws -> T {
        let current = self.generation
        return try await writer.write { db in
            guard current.withLock({ $0 }) == generation else { throw StorageError.replaced }
            return try updates(db)
        }
    }
}

/// The file protection of the database directory (spec 10, D066): iOS encrypts the files, and they are not
/// readable after a restart until the first unlock. After that unlock they stay readable while the iPhone is
/// locked, so a record from the Watch, or from the "Taken" action of a reminder on the Watch, works with the
/// iPhone in a pocket.
enum FileProtection {
    static let level = FileProtectionType.completeUntilFirstUserAuthentication

    /// Only an iOS build that is not a simulator sets the class, and a failure to set it there fails the open. On a Mac and in a
    /// simulator the class makes SQLite fail while the Mac screen is locked, and some volumes reject it.
    /// They only run builds and tests, so they skip it.
    #if os(iOS) && !targetEnvironment(simulator)
    static let isRequired = true
    #else
    static let isRequired = false
    #endif

    static func prepare(directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try protect(directory)
    }

    /// Sets the protection of files that exist. A file from an earlier build can have another level.
    /// The call changes only the attribute of the file. It copies and rebuilds nothing (spec 7.3).
    /// A file that leaves the database directory, such as an exported backup, keeps `.complete` (D066).
    static func protect(files: [URL], level: FileProtectionType = FileProtection.level) throws {
        for file in files where FileManager.default.fileExists(atPath: file.path) {
            try protect(file, level: level)
        }
    }

    static func level(of file: URL) throws -> FileProtectionType? {
        try FileManager.default.attributesOfItem(atPath: file.path)[.protectionKey] as? FileProtectionType
    }

    private static func protect(_ url: URL, level: FileProtectionType = FileProtection.level) throws {
        guard isRequired else { return }
        try FileManager.default.setAttributes([.protectionKey: level], ofItemAtPath: url.path)
    }
}
