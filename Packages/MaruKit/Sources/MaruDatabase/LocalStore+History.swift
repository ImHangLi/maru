import Foundation
import GRDB
import MaruCore

/// Some days of the history, newest first (spec 3 P05).
public struct HistoryPage: Sendable {
    /// Only days with a dose. A day with nothing planned and nothing recorded does not show.
    public let days: [HistoryDay]
    /// Every item, also the archived ones, so a record of an archived item keeps its name.
    public let items: [Item]
    /// A day before the oldest day of the page can have a dose.
    public let hasEarlier: Bool
}

extension LocalStore {
    /// The days `today - 1` back to `today - days`, newest first. `History` has the rules: the history reads
    /// by records, and it shows a dose with no record only when the plan of that day has it (D019).
    ///
    /// It reads only the occurrences of these dates, not the full history (spec 7.3). It writes nothing,
    /// so a planned dose that no generation run stored gets a new occurrence value, not a stored row.
    public func history(
        before today: LocalDate,
        days: Int,
        deviceTimeZone: NamedTimeZone
    ) async throws(StorageError) -> HistoryPage {
        try await read { db in
            try Self.historyPage(db, before: today, days: days, deviceTimeZone: deviceTimeZone)
        }
    }

    /// The read of `history(before:days:deviceTimeZone:)`. The record export reads its pages in one read (D040).
    static func historyPage(
        _ db: Database,
        before today: LocalDate,
        days: Int,
        deviceTimeZone: NamedTimeZone
    ) throws -> HistoryPage {
        let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
        let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
            .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
        let newest = today.adding(days: -1)
        let oldest = today.adding(days: -max(days, 1))
        // The join to the slot is a LEFT JOIN, so an as-needed dose (no slot, D021) loads too. Its item is
        // `occurrence.itemID`, so the item of the schedule has its own name.
        var stored: [StoredHistoryDose] = []
        var asNeeded: [HistoryAsNeededDose] = []
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT occurrence.*, schedule.itemID AS scheduleItemID
                FROM occurrence
                    LEFT JOIN scheduleSlot ON scheduleSlot.id = occurrence.slotID
                    LEFT JOIN schedule ON schedule.id = scheduleSlot.scheduleID
                WHERE occurrence.plannedDate BETWEEN ? AND ?
                ORDER BY occurrence.rowid
                """,
            arguments: [try oldest.text, try newest.text]
        )
        for row in rows {
            let slotID: String? = try row.decode(forColumn: "slotID")
            if slotID == nil {
                let occurrence = try Self.decodeAsNeededOccurrence(row)
                asNeeded.append(
                    HistoryAsNeededDose(occurrence: occurrence, record: try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id))
                )
            } else {
                let occurrence = try Self.decodeOccurrence(row)
                stored.append(
                    StoredHistoryDose(
                        occurrence: occurrence,
                        itemID: try ItemID(text: row.decode(forColumn: "scheduleItemID")),
                        record: try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id)
                    )
                )
            }
        }
        // The events, not the projection, set the bound. A record with a missing projection row stays
        // reachable, so its page reads it and reports `invalidData` (spec 7.3).
        let firstRecord = try String.fetchOne(
            db,
            sql: """
                SELECT MIN(occurrence.plannedDate)
                FROM occurrence
                WHERE EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                """
        ).map(LocalDate.init(text:))
        let earliest = History.earliestDate(schedules: schedules, stored: firstRecord.map { [$0] } ?? [])
        let dates = (1...max(days, 1)).map { today.adding(days: -$0) }.filter { date in earliest.map { date >= $0 } ?? false }
        return HistoryPage(
            days: History.days(
                dates, items: items, schedules: schedules, stored: stored, asNeeded: asNeeded, deviceTimeZone: deviceTimeZone
            ),
            items: items,
            hasEarlier: earliest.map { $0 < oldest } ?? false
        )
    }

    /// Records the first event of a past dose that no generation run stored (spec 3 P05). One transaction stores
    /// the occurrence and the event, so a failure leaves neither.
    ///
    /// The rules of `record(_:scheduleVersionID:)` apply. After `unavailable`, send the same occurrence and the
    /// same event again: the same values again write nothing (D014). Another occurrence with the same slot and
    /// date is `storage(.conflict)`, and nothing is written. Read the history again then.
    @discardableResult
    public func recordBackfill(_ event: IntakeEvent, occurrence: Occurrence) async throws(RecordFailure) -> OccurrenceRecord {
        try await record([(event, occurrence.scheduleVersionID)], inserting: [occurrence], sync: Self.fullSync)[0]
    }
}
