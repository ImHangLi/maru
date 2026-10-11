import GRDB
import MaruCore

extension LocalStore {
    /// The item of each slot of each schedule, in one read.
    ///
    /// A scheduled occurrence has a slot ID and no item ID. The app uses this read to find the item of each occurrence
    /// of today, and does not load every schedule with its versions (spec 9).
    public func itemIDsBySlot() async throws(StorageError) -> [ScheduleSlotID: ItemID] {
        try await read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT scheduleSlot.id, schedule.itemID
                    FROM scheduleSlot JOIN schedule ON schedule.id = scheduleSlot.scheduleID
                    """
            )
            var items: [ScheduleSlotID: ItemID] = [:]
            for row in rows {
                items[try ScheduleSlotID(text: row.decode(forColumn: "id"))] = try ItemID(text: row.decode(forColumn: "itemID"))
            }
            return items
        }
    }

    /// The dose of each schedule version, for the amount line of the rows on Today. A version with no dose has no entry.
    public func doses(of versionIDs: Set<ScheduleVersionID>) async throws(StorageError) -> [ScheduleVersionID: Dose] {
        try await read { db in
            var doses: [ScheduleVersionID: Dose] = [:]
            for id in versionIDs {
                let text = try String.fetchOne(db, sql: "SELECT dose FROM scheduleVersion WHERE id = ?", arguments: [id.text])
                // `Dose` rejects blank text, so a stored dose is never blank.
                if let text {
                    guard let dose = Dose(text) else { throw StorageError.invalidData }
                    doses[id] = dose
                }
            }
            return doses
        }
    }
}
