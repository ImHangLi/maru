import Foundation
import GRDB
import MaruCore

/// The newest taken dose of an active item (D108). The "Last Dose" widget shows it.
public struct LastDose: Equatable, Sendable {
    public let itemID: ItemID
    public let name: String
    /// The intake time of the current taken record. A change of the time moves it.
    public let takenAt: Date
    /// The amount as the user typed it: the amount of the dose for an as-needed item, else the amount of the
    /// schedule version of the dose. `nil` when there is none.
    public let amount: Dose?
    /// The owner for a text: `nil` when the Family has one active member (D123).
    public let owner: DoseOwner?

    public init(itemID: ItemID, name: String, takenAt: Date, amount: Dose?, owner: DoseOwner? = nil) {
        self.itemID = itemID
        self.owner = owner
        self.name = name
        self.takenAt = takenAt
        self.amount = amount
    }
}

extension LocalStore {
    /// The newest taken dose of every active item, for the "Last Dose" widget. `nil` when there is none. An archived item
    /// does not count. A skipped or undone dose does not count. It reads as `readForWidget` does:
    /// read-only, in one read transaction, and never across a restore.
    public static func readLastDoseForWidget(in directory: URL) throws(StorageError) -> LastDose? {
        try readOnly(in: directory) { db, _ in try fetchLastDose(db) }
    }

    /// Each dose with an event or a state row goes through `fetchCheckedRecord`, as the history read does. A projection
    /// that does not match the history is `invalidData`, so the read fails and does not say "no dose" (spec 7.3, T20).
    static func fetchLastDose(_ db: Database) throws -> LastDose? {
        let family = Family(people: try fetchPeople(db))
        let active = Dictionary(uniqueKeysWithValues: try itemsAndSchedules(db).items.filter { !$0.isArchived }.map { ($0.id, $0) })
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT occurrence.id AS id,
                    COALESCE(occurrence.itemID, schedule.itemID) AS itemID,
                    COALESCE(occurrence.dose, scheduleVersion.dose) AS dose
                FROM occurrence
                    LEFT JOIN scheduleSlot ON scheduleSlot.id = occurrence.slotID
                    LEFT JOIN schedule ON schedule.id = scheduleSlot.scheduleID
                    LEFT JOIN scheduleVersion ON scheduleVersion.id = occurrence.scheduleVersionID
                WHERE EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                    OR EXISTS (SELECT 1 FROM occurrenceState WHERE occurrenceID = occurrence.id)
                """
        )
        var newest: LastDose?
        for row in rows {
            let record = try fetchCheckedRecord(db, occurrenceID: OccurrenceID(text: row.decode(forColumn: "id")))
            guard let item = active[try ItemID(text: row.decode(forColumn: "itemID"))],
                  let event = record.currentEvent, event.action == .taken,
                  newest.map({ event.occurredAt > $0.takenAt }) ?? true
            else { continue }
            let text: String? = try row.decode(forColumn: "dose")
            newest = LastDose(itemID: item.id, name: item.name, takenAt: event.occurredAt, amount: text.flatMap(Dose.init),
                              owner: family.owner(of: item))
        }
        return newest
    }
}
