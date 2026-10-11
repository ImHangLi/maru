import GRDB
import MaruCore

extension LocalStore {
    /// The occurrences of an item that have an intake event, with a plan date on or after `date`,
    /// newest first. The read starts at the records, so a row that is no longer planned still shows (D019).
    public func recordedOccurrences(of itemID: ItemID, since date: LocalDate) async throws(StorageError) -> [Occurrence] {
        try await read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.* FROM occurrence
                    JOIN scheduleSlot ON scheduleSlot.id = occurrence.slotID
                    JOIN schedule ON schedule.id = scheduleSlot.scheduleID
                    WHERE schedule.itemID = ? AND occurrence.plannedDate >= ?
                        AND EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                    ORDER BY occurrence.plannedDate DESC, occurrence.plannedTime DESC
                    """,
                arguments: [itemID.text, try date.text]
            ).map(Self.decodeOccurrence)
        }
    }

    /// The as-needed doses of an item that have an intake event, with a date on or after `date`, newest first
    /// (D021). They have no slot, so `recordedOccurrences(of:since:)` does not read them.
    public func recordedAsNeededOccurrences(
        of itemID: ItemID,
        since date: LocalDate
    ) async throws(StorageError) -> [AsNeededOccurrence] {
        try await read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM occurrence
                    WHERE itemID = ? AND plannedDate >= ?
                        AND EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                    ORDER BY plannedDate DESC, plannedTime DESC, rowid DESC
                    """,
                arguments: [itemID.text, try date.text]
            ).map(Self.decodeAsNeededOccurrence)
        }
    }

    /// The items with a schedule whose reminders are off, in one read. Today and My Items show their state (T07).
    public func itemIDsWithRemindersOff() async throws(StorageError) -> Set<ItemID> {
        try await read { db in
            Set(try String.fetchAll(db, sql: "SELECT DISTINCT itemID FROM schedule WHERE isEnabled = 0").map(ItemID.init(text:)))
        }
    }
}
