import Foundation
import GRDB

extension LocalStore {
    /// Tells whether `directory` holds a database. A damaged or empty file throws `corrupt`, as `init(directory:)` does.
    ///
    /// The widget uses it so that it never creates an empty database before the app moved the real one (D048).
    public static func hasDatabase(at directory: URL) throws(StorageError) -> Bool {
        do {
            return try hasDatabase(in: directory)
        } catch {
            throw StorageError(error)
        }
    }

    /// Copies the database of an earlier directory into `directory`, one time (D048).
    ///
    /// Call it before `init(directory:)`. It does nothing when `directory` has a database already, and when
    /// `earlier` has none. The copy never deletes or changes the data of `earlier`, so the user still has it
    /// after any failure. A failure throws, and the caller must not open `directory`: an empty database there
    /// would hide the data (spec 7.3, T37).
    ///
    /// The steps: `VACUUM INTO` makes one consistent file under a temporary name. The integrity check and the foreign
    /// key check of SQLite read the copy. The file gets its protection and a full flush. Then an atomic rename that
    /// never replaces a file gives it the final name, the same way as `create` does. A stop before the rename
    /// leaves only temporary files, and the next launch removes them and starts again.
    public static func adopt(from earlier: URL, into directory: URL) throws(StorageError) {
        opening.lock()
        defer { opening.unlock() }
        do {
            try FileProtection.prepare(directory: directory)
            if try hasDatabase(in: directory) { return }
            guard try hasDatabase(in: earlier) else { return }
            removeTemporaryFiles(in: directory)
            defer { removeTemporaryFiles(in: directory) }
            let temporary = directory.appendingPathComponent(temporaryPrefix + UUID().uuidString)
            let old = try DatabaseQueue(path: earlier.appendingPathComponent(fileName).path)
            try old.writeWithoutTransaction { db in
                try db.execute(sql: "VACUUM INTO ?", arguments: [temporary.path])
            }
            try old.close()
            try FileProtection.protect(files: [temporary])
            let copy = try DatabaseQueue(path: temporary.path)
            try copy.read { db in
                guard try String.fetchOne(db, sql: "PRAGMA integrity_check") == "ok",
                      try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").isEmpty
                else { throw StorageError.corrupt }
            }
            try copy.close()
            guard flush(temporary) else { throw StorageError.unavailable }
            let database = directory.appendingPathComponent(fileName)
            guard renamex_np(temporary.path, database.path, UInt32(RENAME_EXCL)) == 0
                || FileManager.default.fileExists(atPath: database.path)
            else { throw StorageError.unavailable }
            guard flush(directory) else { throw StorageError.unavailable }
        } catch {
            throw StorageError(error)
        }
    }
}
