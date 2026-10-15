import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// Stores an occurrence. The same value again changes nothing. Another occurrence with the same ID
    /// or the same key (slot and plan date) is `StorageError.conflict` (T17).
    /// `generation` is the generation of the data that the caller read. See `checkedWrite`.
    public func save(_ occurrence: Occurrence, generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            try Self.insert(occurrence, db)
        }
    }

    /// A scheduled occurrence. An as-needed occurrence is not an `Occurrence`, so its ID gives `nil` here.
    /// See `asNeededOccurrence(id:)`.
    public func occurrence(id: OccurrenceID) async throws(StorageError) -> Occurrence? {
        try await read { db in
            try Self.fetchOccurrence(db, id: id)
        }
    }

    /// The occurrence of one slot on one plan date. Today and yesterday are different occurrences.
    public func occurrence(slotID: ScheduleSlotID, on plannedDate: LocalDate) async throws(StorageError) -> Occurrence? {
        try await read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT * FROM occurrence WHERE slotID = ? AND plannedDate = ?",
                arguments: [slotID.text, plannedDate.text]
            ).map(Self.decodeOccurrence)
        }
    }

    /// The record transaction (spec 7.2). It checks the occurrence, the schedule version, and the current
    /// state, then writes the event and the projection in one transaction.
    ///
    /// The call returns only after the transaction commits and the storage medium has it, so the record
    /// is still there after a power loss. Show "recorded" only after it returns.
    /// On an error nothing is written, and the same event can be sent again (T19). One error is different:
    /// when the commit works and the flush to the storage medium fails, the event is stored and the call
    /// throws `StorageError.unavailable`. The same event again writes nothing and flushes again.
    /// See `RecordFailure` for what the caller must do then.
    /// The event ID is the idempotency key: the same event again changes nothing and returns the same record (T18).
    /// A projection that disagrees with the stored history is `StorageError.invalidData`, also for the same event again.
    ///
    /// - Parameter scheduleVersionID: The schedule version of the occurrence that the user saw.
    /// The call records with generation 0. See `record(_:generation:)`.
    @discardableResult
    public func record(
        _ event: IntakeEvent,
        scheduleVersionID: ScheduleVersionID
    ) async throws(RecordFailure) -> OccurrenceRecord {
        try await record(event, scheduleVersionID: scheduleVersionID, sync: Self.fullSync)
    }

    /// Records several events in one transaction, for example every open item of a time slot (D021).
    ///
    /// Each event gets the checks of `record(_:scheduleVersionID:)`. One failed check writes none of the events,
    /// so the slot is either recorded or left as it was. The same events again write nothing, so the rules
    /// of `RecordFailure` apply to the whole list: after `unavailable`, send the same list again.
    ///
    /// - Parameter generation: The generation of the data that the caller read: 0, or the generation that
    ///   the last `restore(_:)` gave. Another value is `RecordFailure.replaced`, and nothing is written.
    /// - Returns: The record of each occurrence, in the order of the events.
    @discardableResult
    public func record(
        _ events: [(event: IntakeEvent, scheduleVersionID: ScheduleVersionID)],
        generation: Int = 0,
        currentPlan: (@Sendable () -> OccurrenceGeneration?)? = nil,
        restoreEpoch: Int? = nil
    ) async throws(RecordFailure) -> [OccurrenceRecord] {
        try await record(events, generation: generation, currentPlan: currentPlan, restoreEpoch: restoreEpoch, sync: Self.fullSync)
    }

    /// `sync` is for tests. See `flush`.
    func record(
        _ event: IntakeEvent,
        scheduleVersionID: ScheduleVersionID,
        sync: @Sendable (Int32) -> Int32
    ) async throws(RecordFailure) -> OccurrenceRecord {
        try await record([(event, scheduleVersionID)], sync: sync)[0]
    }

    /// `inserting` are new occurrences that the same transaction stores before the events (a backfill).
    func record(
        _ events: [(event: IntakeEvent, scheduleVersionID: ScheduleVersionID)],
        inserting occurrences: [Occurrence] = [],
        generation: Int = 0,
        currentPlan: (@Sendable () -> OccurrenceGeneration?)? = nil,
        restoreEpoch: Int? = nil,
        sync: @Sendable (Int32) -> Int32
    ) async throws(RecordFailure) -> [OccurrenceRecord] {
        let directory = directory
        return try await commitRecord(generation: generation, sync: sync) { db in
            // The widget read the data at this epoch. A restore changes it while it holds the writer, so the check
            // and the write are in order with it (D048).
            if let restoreEpoch, Self.restoreEpoch(in: directory) != restoreEpoch { throw RecordFailure.replaced }
            for occurrence in occurrences {
                try Self.insert(occurrence, db)
            }
            // The plan of now reads the clock and the device time zone here, after the writer is free, so a
            // request that waited for the writer past midnight records nothing (D071).
            let plan = try currentPlan.map { currentPlan in
                guard let plan = currentPlan() else { throw RecordFailure.storage(.unavailable) }
                return plan
            }
            return try events.map { event, scheduleVersionID in
                guard let occurrence = try Self.fetchOccurrence(db, id: event.occurrenceID) else {
                    throw RecordFailure.unknownOccurrence
                }
                guard occurrence.scheduleVersionID == scheduleVersionID else { throw RecordFailure.versionChanged }
                if let plan { try Self.requireCurrentPlan(occurrence, plan, db) }
                return try Self.append(event, db)
            }
        }
    }

    /// The widget records only a dose that the plan of now still has: its item is active, its slot is in the
    /// plan, and its schedule version is the planned one. The occurrence row of an archived item or of a removed
    /// slot stays, and a stale widget button must not record it (D048). The dose must also be of today in its own
    /// time zone at the time of the plan, so a request from before midnight records nothing after it (D071).
    /// The check and the clock of the plan run in the record transaction.
    static func requireCurrentPlan(_ occurrence: Occurrence, _ plan: OccurrenceGeneration, _ db: Database) throws {
        let (items, schedules) = try Self.itemsAndSchedules(db)
        let planned = plan.outcome(items: items, schedules: schedules, stored: []).occurrences
        guard occurrence.plannedDate == LocalDate(plan.now, in: occurrence.timeZone),
              planned.contains(where: {
                  $0.key == occurrence.key && $0.scheduleVersionID == occurrence.scheduleVersionID
              })
        else { throw RecordFailure.versionChanged }
    }

    /// Runs one record transaction, and returns only after the storage medium has the commit.
    ///
    /// A `generation` that is not the current one is `RecordFailure.replaced`. See `checkedWrite`.
    func commitRecord<T: Sendable>(
        generation: Int,
        sync: @Sendable (Int32) -> Int32,
        _ updates: @Sendable (Database) throws -> T
    ) async throws(RecordFailure) -> T {
        do {
            let result = try await checkedWrite(generation: generation, updates)
            // The commit synced the WAL file to the drive. Wait until the drive wrote it to the storage medium.
            // A failed flush is no success, also when another sync call works.
            guard Self.flush(walFile, sync: sync) else { throw StorageError.unavailable }
            return result
        } catch {
            throw Self.recordFailure(error)
        }
    }

    /// The failure of a record transaction, from any error that the transaction or the flush threw.
    static func recordFailure(_ error: any Error) -> RecordFailure {
        if let failure = error as? RecordFailure { return failure }
        if let storage = error as? StorageError, storage == .replaced { return .replaced }
        return .storage(StorageError(error))
    }

    /// Adds an event to the checked history of its occurrence, and writes the event and the projection.
    /// The same event again writes nothing.
    static func append(_ event: IntakeEvent, _ db: Database) throws -> OccurrenceRecord {
        // The domain decides. The store does not repeat the rules of `OccurrenceRecord`.
        var record = try fetchCheckedRecord(db, occurrenceID: event.occurrenceID)
        let storedCount = record.events.count
        do {
            try record.record(event)
        } catch let error as MaruCore.RecordError {
            throw RecordFailure.rejected(error)
        }
        guard record.events.count > storedCount else { return record }
        try insert(event, position: storedCount, db)
        try writeState(of: record, db)
        return record
    }

    /// The checked record of each occurrence, for the rows of Today. An occurrence with no event has an empty record.
    /// A projection that disagrees with the history is `StorageError.invalidData` (T20).
    public func records(of occurrenceIDs: [OccurrenceID]) async throws(StorageError) -> [OccurrenceID: OccurrenceRecord] {
        try await read { db in
            var records: [OccurrenceID: OccurrenceRecord] = [:]
            for id in occurrenceIDs {
                records[id] = try Self.fetchCheckedRecord(db, occurrenceID: id)
            }
            return records
        }
    }

    /// The event history of an occurrence, with every revision link (T20). It is empty when nothing is recorded.
    public func history(of occurrenceID: OccurrenceID) async throws(StorageError) -> OccurrenceRecord {
        try await read { db in
            try Self.fetchRecord(db, occurrenceID: occurrenceID)
        }
    }

    /// The one valid state of an occurrence. The projection and the event history must agree on it (T20).
    /// A projection that disagrees with the history is `StorageError.invalidData`.
    public func status(of occurrenceID: OccurrenceID) async throws(StorageError) -> OccurrenceStatus {
        try await read { db in
            try Self.fetchCheckedRecord(db, occurrenceID: occurrenceID).status
        }
    }

    private static func insert(_ event: IntakeEvent, position: Int, _ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO intakeEvent (id, occurrenceID, position, action, occurredAt, recordedAt, source, supersedes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                event.id.text, event.occurrenceID.text, position, event.action.rawValue, event.occurredAt.storedSeconds,
                event.recordedAt.storedSeconds, event.source.rawValue, event.supersedes?.text,
            ]
        )
    }

    /// Writes the projection of a record: one row for a taken or skipped occurrence, and no row after an undo.
    private static func writeState(of record: OccurrenceRecord, _ db: Database) throws {
        if let current = record.currentEvent {
            try db.execute(
                sql: """
                    INSERT INTO occurrenceState (occurrenceID, eventID, status) VALUES (?, ?, ?)
                    ON CONFLICT (occurrenceID) DO UPDATE SET eventID = excluded.eventID, status = excluded.status
                    """,
                arguments: [record.occurrenceID.text, current.id.text, current.action.rawValue]
            )
        } else {
            try db.execute(sql: "DELETE FROM occurrenceState WHERE occurrenceID = ?", arguments: [record.occurrenceID.text])
        }
    }

    /// Inserts an occurrence. A stored occurrence with the same ID or the same key must be the same value.
    static func insert(_ occurrence: Occurrence, _ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO occurrence (id, slotID, plannedDate, plannedTime, timeZone, scheduleVersionID)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT DO NOTHING
                """,
            arguments: [
                occurrence.id.text, occurrence.slotID.text, occurrence.plannedDate.text, occurrence.plannedTime.text,
                occurrence.timeZone.identifier, occurrence.scheduleVersionID.text,
            ]
        )
        guard try fetchOccurrence(db, id: occurrence.id) == occurrence else { throw StorageError.conflict }
    }

    /// A scheduled occurrence. An as-needed occurrence with this ID gives `nil`.
    private static func fetchOccurrence(_ db: Database, id: OccurrenceID) throws -> Occurrence? {
        try Row.fetchOne(
            db,
            sql: "SELECT * FROM occurrence WHERE id = ? AND slotID IS NOT NULL",
            arguments: [id.text]
        ).map(decodeOccurrence)
    }

    static func decodeOccurrence(_ row: Row) throws -> Occurrence {
        Occurrence(
            id: try OccurrenceID(text: row.decode(forColumn: "id")),
            slotID: try ScheduleSlotID(text: row.decode(forColumn: "slotID")),
            plannedDate: try LocalDate(text: row.decode(forColumn: "plannedDate")),
            plannedTime: try WallClockTime(text: row.decode(forColumn: "plannedTime")),
            timeZone: try NamedTimeZone(text: row.decode(forColumn: "timeZone")),
            scheduleVersionID: try ScheduleVersionID(text: row.decode(forColumn: "scheduleVersionID"))
        )
    }

    /// Loads the history and checks the projection against it. The projection must name the current event
    /// and its action, and it must have no row when the occurrence is unrecorded.
    ///
    /// A disagreement is `StorageError.invalidData`. Nothing repairs it here: the caller gets the error,
    /// and both tables stay as they are.
    static func fetchCheckedRecord(_ db: Database, occurrenceID: OccurrenceID) throws -> OccurrenceRecord {
        let record = try fetchRecord(db, occurrenceID: occurrenceID)
        let state = try Row.fetchOne(
            db,
            sql: "SELECT eventID, status FROM occurrenceState WHERE occurrenceID = ?",
            arguments: [occurrenceID.text]
        ).map { row in
            (
                eventID: try IntakeEventID(text: row.decode(forColumn: "eventID")),
                action: try IntakeAction(text: row.decode(forColumn: "status"))
            )
        }
        guard state?.eventID == record.currentEvent?.id, state?.action == record.currentEvent?.action else {
            throw StorageError.invalidData
        }
        return record
    }

    /// Loads the history through `OccurrenceRecord.record`, so stored events that break a record rule do not load.
    private static func fetchRecord(_ db: Database, occurrenceID: OccurrenceID) throws -> OccurrenceRecord {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT * FROM intakeEvent WHERE occurrenceID = ? ORDER BY position",
            arguments: [occurrenceID.text]
        )
        var record = OccurrenceRecord(occurrenceID: occurrenceID)
        try domain {
            for row in rows {
                let supersedes: String? = try row.decode(forColumn: "supersedes")
                try record.record(
                    IntakeEvent(
                        id: IntakeEventID(text: row.decode(forColumn: "id")),
                        occurrenceID: occurrenceID,
                        action: IntakeAction(text: row.decode(forColumn: "action")),
                        occurredAt: Date(storedSeconds: row.decode(forColumn: "occurredAt")),
                        recordedAt: Date(storedSeconds: row.decode(forColumn: "recordedAt")),
                        source: EventSource(text: row.decode(forColumn: "source")),
                        supersedes: supersedes.map(IntakeEventID.init(text:))
                    )
                )
            }
        }
        return record
    }
}
