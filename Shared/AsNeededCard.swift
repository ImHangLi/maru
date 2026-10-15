import Foundation
import MaruCore
import MaruDatabase

/// The "As needed" card of Today: the items with no active schedule, and the doses of today (D021).
struct AsNeededCard: Equatable, Sendable {
    /// One dose of today and its record. A correction revises its last event.
    struct Dose: Identifiable, Equatable, Sendable {
        let occurrence: AsNeededOccurrence
        var record: OccurrenceRecord

        var id: OccurrenceID { occurrence.id }
        /// The time of the current taken or skipped event, not the time of the first record.
        var time: Date? { record.currentEvent?.occurredAt }
    }

    /// One item and its doses of today, in the order of the record.
    struct Row: Identifiable, Equatable, Sendable {
        let itemID: ItemID
        let look: TodaySnapshot.ItemLook
        /// `false` for an item with doses of today that is no longer as needed, for example after the user
        /// added a time to it. Its row shows the doses and no record button.
        let canRecord: Bool
        var doses: [Dose]
        /// The usual amount of the item. A new dose copies it (D091). `nil` when the item has none.
        var amount: MaruCore.Dose?
        /// When the user last took a dose of the item, also on an earlier day (D091). `nil` when there is none.
        var lastTaken: Date?

        var id: ItemID { itemID }
    }

    var rows: [Row] = []
    /// The date of the read. `nil` for the empty card.
    var date: LocalDate?

    var isEmpty: Bool { rows.isEmpty }

    init() {}

    /// - Parameter items: Every item. An archived item and its doses do not show. The store keeps the doses.
    init(_ day: AsNeededDay, items: [Item], on date: LocalDate) {
        self.date = date
        let looks = Dictionary(uniqueKeysWithValues: items.filter { !$0.isArchived }.map {
            ($0.id, TodaySnapshot.ItemLook(
                itemID: $0.id, name: $0.name, form: $0.form, color: $0.color, imageReference: $0.imageReference
            ))
        })
        rows = day.items.compactMap { item in
            looks[item.id].map {
                Row(
                    itemID: item.id, look: $0, canRecord: true, doses: [],
                    amount: item.asNeededDose, lastTaken: day.lastTaken[item.id]
                )
            }
        }
        for record in day.records {
            let dose = Dose(occurrence: record.occurrence, record: record.record)
            if let index = rows.firstIndex(where: { $0.itemID == record.occurrence.itemID }) {
                rows[index].doses.append(dose)
            } else if let look = looks[record.occurrence.itemID] {
                rows.append(Row(
                    itemID: record.occurrence.itemID, look: look, canRecord: false, doses: [dose],
                    lastTaken: day.lastTaken[record.occurrence.itemID]
                ))
            }
        }
    }

    /// Puts a committed record in place. A new dose goes at the end of its item. An undone dose leaves the card,
    /// like in the next read.
    mutating func apply(_ record: OccurrenceRecord, of occurrence: AsNeededOccurrence) {
        guard let row = rows.firstIndex(where: { $0.itemID == occurrence.itemID }) else { return }
        if let dose = rows[row].doses.firstIndex(where: { $0.id == occurrence.id }) {
            if record.status == .unrecorded {
                rows[row].doses.remove(at: dose)
            } else {
                rows[row].doses[dose].record = record
            }
        } else if record.status != .unrecorded {
            rows[row].doses.append(Dose(occurrence: occurrence, record: record))
        }
        // "Last dose" follows every record, undo, and time change at once (D091). A taken dose of the shown day
        // gives the newest time. With none left, the value of an earlier day stays, and a value of the shown day
        // goes until the read that the model starts after an undo or a skip gives the stored one.
        if let newest = rows[row].doses.compactMap({ $0.record.status == .taken ? $0.time : nil }).max() {
            rows[row].lastTaken = newest
        } else if let last = rows[row].lastTaken, LocalDate(last, in: occurrence.timeZone) >= occurrence.plannedDate {
            rows[row].lastTaken = nil
        }
    }
}

extension AsNeededCard.Dose {
    init(_ dose: HistoryAsNeededDose) {
        self.init(occurrence: dose.occurrence, record: dose.record)
    }
}
