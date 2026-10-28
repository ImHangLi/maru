import Foundation
import GRDB
import MaruCore

/// The newest taken dose of an active item (D108). The "Last Dose" widget and Siri show it.
public struct LastDose: Equatable, Sendable {
    public let itemID: ItemID
    public let name: String
    /// The intake time of the current taken record. A change of the time moves it.
    public let takenAt: Date
    /// The amount as the user typed it: the amount of the dose for an as-needed item, else the amount of the
    /// schedule version of the dose. `nil` when there is none.
    public let amount: Dose?

    public init(itemID: ItemID, name: String, takenAt: Date, amount: Dose?) {
        self.itemID = itemID
        self.name = name
        self.takenAt = takenAt
        self.amount = amount
    }
}

extension LocalStore {
    /// The newest taken dose of `itemID`, or of every active item when `itemID` is `nil`. `nil` when there is none.
    /// An archived item does not count. A skipped or undone dose does not count.
    public func lastDose(of itemID: ItemID? = nil) async throws(StorageError) -> LastDose? {
        try await read { db in try Self.fetchLastDose(db, of: itemID) }
    }

    /// The newest taken dose of every active item, for the "Last Dose" widget. It reads as `readForWidget` does:
    /// read-only, in one read transaction, and never across a restore.
    public static func readLastDoseForWidget(in directory: URL) throws(StorageError) -> LastDose? {
        try readOnly(in: directory) { db, _ in try fetchLastDose(db, of: nil) }
    }

    /// The projection names the current event of each dose, as for "Last dose" of an as-needed item (D091).
    static func fetchLastDose(_ db: Database, of itemID: ItemID?) throws -> LastDose? {
        let active = Dictionary(uniqueKeysWithValues: try itemsAndSchedules(db).items.filter { !$0.isArchived }.map { ($0.id, $0) })
        let rows = try Row.fetchCursor(
            db,
            sql: """
                SELECT COALESCE(occurrence.itemID, schedule.itemID) AS itemID,
                    intakeEvent.occurredAt AS occurredAt,
                    COALESCE(occurrence.dose, scheduleVersion.dose) AS dose
                FROM occurrenceState
                    JOIN intakeEvent ON intakeEvent.id = occurrenceState.eventID
                    JOIN occurrence ON occurrence.id = occurrenceState.occurrenceID
                    LEFT JOIN scheduleSlot ON scheduleSlot.id = occurrence.slotID
                    LEFT JOIN schedule ON schedule.id = scheduleSlot.scheduleID
                    LEFT JOIN scheduleVersion ON scheduleVersion.id = occurrence.scheduleVersionID
                WHERE occurrenceState.status = 'taken'
                    AND (? IS NULL OR COALESCE(occurrence.itemID, schedule.itemID) = ?)
                ORDER BY intakeEvent.occurredAt DESC
                """,
            arguments: [itemID?.text, itemID?.text]
        )
        while let row = try rows.next() {
            guard let item = active[try ItemID(text: row.decode(forColumn: "itemID"))] else { continue }
            let seconds: Double = try row.decode(forColumn: "occurredAt")
            let text: String? = try row.decode(forColumn: "dose")
            return LastDose(itemID: item.id, name: item.name, takenAt: Date(storedSeconds: seconds), amount: text.flatMap(Dose.init))
        }
        return nil
    }
}
