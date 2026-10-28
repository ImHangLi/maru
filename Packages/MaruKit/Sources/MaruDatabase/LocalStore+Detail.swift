import GRDB
import MaruCore

extension LocalStore {
    /// The items with a schedule whose reminders are off, in one read. Today and My Items show their state (T07).
    public func itemIDsWithRemindersOff() async throws(StorageError) -> Set<ItemID> {
        try await read { db in
            Set(try String.fetchAll(db, sql: "SELECT DISTINCT itemID FROM schedule WHERE isEnabled = 0").map(ItemID.init(text:)))
        }
    }

    /// Whether at least `count` doses have a record, taken or skipped. An undo removes the record, so it does not count.
    /// The Maru Pro card of Today reads it (D107). It reads no name, time, or item.
    public func hasRecords(atLeast count: Int) async throws(StorageError) -> Bool {
        try await read { db in
            let found = try Int.fetchOne(
                db, sql: "SELECT COUNT(*) FROM (SELECT 1 FROM occurrenceState LIMIT ?)", arguments: [count]
            ) ?? 0
            return found >= count
        }
    }
}
