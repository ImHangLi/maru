import GRDB
import MaruCore

extension LocalStore {
    /// The items with a schedule whose reminders are off, in one read. Today and My Items show their state (T07).
    public func itemIDsWithRemindersOff() async throws(StorageError) -> Set<ItemID> {
        try await read { db in
            Set(try String.fetchAll(db, sql: "SELECT DISTINCT itemID FROM schedule WHERE isEnabled = 0").map(ItemID.init(text:)))
        }
    }
}
