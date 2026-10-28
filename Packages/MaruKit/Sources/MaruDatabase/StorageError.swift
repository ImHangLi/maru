import GRDB
import MaruCore

/// Why a database operation failed.
///
/// No case carries SQL, an SQLite message, or a stored value, so the error is safe to log (spec 10).
/// The store never deletes or replaces a database file to recover from one of these (spec 7.3, T37).
public enum StorageError: Error, Equatable, Sendable {
    /// The database file is missing or empty where a database was, is not an SQLite database, or is damaged.
    case corrupt
    /// A migration failed and rolled back. The database stays at the version it had.
    case migrationFailed
    /// A newer version of the app wrote the database.
    case newerSchema
    /// A value breaks a domain rule or does not come back from the database as it went in.
    /// A stored value of this kind does not load, and a new one is not saved.
    case invalidData
    /// The write conflicts with stored data: a duplicate key, an unknown parent, or a change to an immutable value.
    case conflict
    /// The disk is full.
    case diskFull
    /// The files cannot be read or written now. After a restart and before the first unlock, file protection can be the cause (spec 10, D066).
    case unavailable
    /// The task was cancelled before the transaction committed.
    case cancelled
    /// A restore replaced the data after the caller read it (D040). Nothing was written. Read the data again.
    case replaced
    /// Another failure. `sqliteCode` is the primary SQLite result code, when SQLite reported one.
    case failed(sqliteCode: Int32?)

    init(_ error: any Error) {
        switch error {
        case let error as StorageError:
            self = error
        case let error as DatabaseError:
            switch error.resultCode {
            case .SQLITE_CORRUPT, .SQLITE_NOTADB:
                self = .corrupt
            case .SQLITE_CONSTRAINT:
                self = .conflict
            case .SQLITE_FULL:
                self = .diskFull
            case .SQLITE_IOERR, .SQLITE_AUTH, .SQLITE_CANTOPEN, .SQLITE_PERM, .SQLITE_READONLY, .SQLITE_BUSY:
                self = .unavailable
            default:
                self = .failed(sqliteCode: error.resultCode.rawValue)
            }
        case is DecodeRule:
            self = .invalidData
        case is RowDecodingError:
            self = .invalidData
        case is CancellationError:
            self = .cancelled
        default:
            self = .failed(sqliteCode: nil)
        }
    }
}

/// Why the record transaction gave no record. The transaction wrote nothing, and the occurrence keeps
/// the state it had (T19), with one exception.
///
/// The exception is `storage(.unavailable)`: the event can already be stored, because the commit worked
/// and the flush to the storage medium failed. The caller cannot tell this from a failure before the commit.
/// So after this error the caller must:
/// - keep the same event and the same schedule version ID,
/// - read the stored state, and not treat the occurrence as unrecorded,
/// - send the same event again, and not create another event automatically,
/// - show success only after this retry returns.
public enum RecordFailure: Error, Equatable, Sendable {
    /// No occurrence has the occurrence ID of the event.
    case unknownOccurrence
    /// The occurrence has another schedule version than the one that the caller saw.
    case versionChanged
    /// The item of the occurrence has another owner than when the caller listed the dose (D123). Nothing was written. A quick
    /// action must not record a dose that the user saw under another member.
    case ownerChanged
    /// A domain rule rejected the event, for example a second first event for the occurrence (T18).
    case rejected(MaruCore.RecordError)
    /// The database failed. The user can try again. After `unavailable`, the event can already be stored.
    case storage(StorageError)
    /// A restore replaced the data after the caller read it (D040). Nothing was written. Read the data again.
    case replaced
}
