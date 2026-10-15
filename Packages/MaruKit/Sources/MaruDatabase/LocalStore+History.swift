import Foundation
import GRDB
import MaruCore

/// The planned doses of each day of the graph range and how many of them are taken (D041).
public struct HistoryCounts: Sendable {
    /// The first date that can have a dose. `nil` when there is no plan and no record.
    public let firstDay: LocalDate?
    /// Only days with a planned dose.
    public let days: [LocalDate: HistoryDayCount]
}

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
        let (items, schedules) = try Self.itemsAndSchedules(db)
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
        let earliest = try Self.firstDay(db, schedules: schedules)
        let dates = (1...max(days, 1)).map { today.adding(days: -$0) }.filter { date in earliest.map { date >= $0 } ?? false }
        return HistoryPage(
            days: History.days(
                dates, items: items, schedules: schedules, stored: stored, asNeeded: asNeeded, deviceTimeZone: deviceTimeZone
            ),
            items: items,
            hasEarlier: earliest.map { $0 < oldest } ?? false
        )
    }

    /// The counts of the days from `oldest` to `today` for the graph (D041). `History.counts` has the rules,
    /// so a day has the same doses as in the timeline.
    ///
    /// One query reads every stored planned dose of the range with its state, so a year reads fast. The state
    /// comes from the projection. The timeline checks the projection against the events (spec 7.3).
    public func historyCounts(
        from oldest: LocalDate,
        through today: LocalDate,
        deviceTimeZone: NamedTimeZone
    ) async throws(StorageError) -> HistoryCounts {
        try await read { db in
            let (items, schedules) = try Self.itemsAndSchedules(db)
            guard let firstDay = try Self.firstDay(db, schedules: schedules) else {
                return HistoryCounts(firstDay: nil, days: [:])
            }
            let from = max(oldest, firstDay)
            guard from <= today else { return HistoryCounts(firstDay: firstDay, days: [:]) }
            let stored = try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.slotID, occurrence.plannedDate, occurrenceState.status,
                        EXISTS (SELECT 1 FROM intakeEvent WHERE intakeEvent.occurrenceID = occurrence.id) AS hasEvents
                    FROM occurrence
                        LEFT JOIN occurrenceState ON occurrenceState.occurrenceID = occurrence.id
                    WHERE occurrence.slotID IS NOT NULL AND occurrence.plannedDate BETWEEN ? AND ?
                    """,
                arguments: [try from.text, try today.text]
            ).map { row in
                let status: String? = try row.decode(forColumn: "status")
                return StoredDoseState(
                    key: OccurrenceKey(
                        slotID: try ScheduleSlotID(text: row.decode(forColumn: "slotID")),
                        plannedDate: try LocalDate(text: row.decode(forColumn: "plannedDate"))
                    ),
                    hasEvents: try row.decode(forColumn: "hasEvents"),
                    isTaken: try status.map(IntakeAction.init(text:)) == .taken
                )
            }
            let dates = (0...today.days(since: from)).map { from.adding(days: $0) }
            return HistoryCounts(
                firstDay: firstDay,
                days: History.counts(dates, items: items, schedules: schedules, stored: stored, deviceTimeZone: deviceTimeZone)
            )
        }
    }

    /// The first date that can have a dose: the first schedule version, or the first record.
    /// The events, not the projection, set the bound. A record with a missing projection row stays
    /// reachable, so its page reads it and reports `invalidData` (spec 7.3).
    private static func firstDay(_ db: Database, schedules: [Schedule]) throws -> LocalDate? {
        let firstRecord = try String.fetchOne(
            db,
            sql: """
                SELECT MIN(occurrence.plannedDate)
                FROM occurrence
                WHERE EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                """
        ).map(LocalDate.init(text:))
        return History.earliestDate(schedules: schedules, stored: firstRecord.map { [$0] } ?? [])
    }

    /// Records the first event of a past dose that no generation run stored (spec 3 P05). One transaction stores
    /// the occurrence and the event, so a failure leaves neither.
    ///
    /// The rules of `record(_:scheduleVersionID:)` apply. After `unavailable`, send the same occurrence and the
    /// same event again: the same values again write nothing (D014). Another occurrence with the same slot and
    /// date is `storage(.conflict)`, and nothing is written. Read the history again then.
    /// See `record(_:generation:)` for `generation`.
    @discardableResult
    public func recordBackfill(
        _ event: IntakeEvent,
        occurrence: Occurrence,
        generation: Int = 0
    ) async throws(RecordFailure) -> OccurrenceRecord {
        try await record(
            [(event, occurrence.scheduleVersionID)], inserting: [occurrence], generation: generation, sync: Self.fullSync
        )[0]
    }
}
