import GRDB
import SQLite3
import os

/// Records the sync calls that SQLite makes on the WAL file of one connection.
///
/// SQLite calls the operating system through a table of functions that each open file has.
/// The probe gives the WAL file a copy of its table with one changed entry. This entry records
/// the flags of a sync call, and then calls the original function. One test uses the probe at a time.
enum SyncProbe {
    private struct NoWALFile: Error {}

    private nonisolated(unsafe) static var original: UnsafePointer<sqlite3_io_methods>?
    private static let flags = OSAllocatedUnfairLock<[Int32]>(initialState: [])

    static func attach(to db: Database) throws {
        let file = try walFile(of: db)
        original = file.pointee.pMethods
        let methods = UnsafeMutablePointer<sqlite3_io_methods>.allocate(capacity: 1)
        methods.initialize(to: file.pointee.pMethods.pointee)
        methods.pointee.xSync = { file, syncFlags in
            SyncProbe.flags.withLock { $0.append(syncFlags) }
            return SyncProbe.original!.pointee.xSync(file, syncFlags)
        }
        file.pointee.pMethods = UnsafePointer(methods)
    }

    /// Gives the WAL file its own table again, and returns the flags of each sync call since `attach`.
    static func detach(from db: Database) throws -> [Int32] {
        let file = try walFile(of: db)
        UnsafeMutablePointer(mutating: file.pointee.pMethods)?.deallocate()
        file.pointee.pMethods = original
        return flags.withLock { $0 }
    }

    /// In WAL mode, the journal file of a connection is its WAL file.
    private static func walFile(of db: Database) throws -> UnsafeMutablePointer<sqlite3_file> {
        var file: UnsafeMutablePointer<sqlite3_file>?
        let code = sqlite3_file_control(db.sqliteConnection, "main", SQLITE_FCNTL_JOURNAL_POINTER, &file)
        guard code == SQLITE_OK, let file, file.pointee.pMethods != nil else { throw NoWALFile() }
        return file
    }
}
