import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// Generates the occurrences of today and of the days next to it, and returns them in the order
    /// of the planned instant (spec 7.3, 8.1). `OccurrenceGeneration` has the rules. The store only loads and writes.
    ///
    /// The run finds a stored occurrence by its key (slot and plan date), so a second run creates nothing,
    /// and a slot with a record gets no second occurrence on that date (T17).
    /// A stored occurrence with no intake event and a date that is not in the past, in its stored time zone
    /// and in the time zone of the plan, follows the plan of now:
    /// the run updates its planned time, its time zone, and its schedule version, and keeps its ID.
    /// This is the one write that changes a stored occurrence. An occurrence with an intake event never changes (spec 7.2).
    /// `save(_:)` still rejects a change to a stored occurrence.
    /// The run deletes nothing.
    ///
    /// - Parameters:
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the schedule versions that follow it.
    ///   - generation: The generation of the data that the caller read. See `checkedWrite`.
    @discardableResult
    public func generateOccurrences(
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        generation: Int = 0
    ) async throws(StorageError) -> [Occurrence] {
        try await generate(at: now, deviceTimeZone: deviceTimeZone, generation: generation).occurrences
    }

    /// The result of one generation run.
    public struct GenerationRun: Sendable {
        /// The occurrences, in the order of the planned instant.
        public let occurrences: [Occurrence]
        /// The time zone of each schedule version that the run read: the fixed zones, and the device zone
        /// for a version that follows the device. A change of the date in one of them can change the result.
        public let planZones: Set<NamedTimeZone>
    }

    /// Runs `generateOccurrences(at:deviceTimeZone:)`, and also returns the time zones of the plans that it read.
    public func generate(
        at now: Date, deviceTimeZone: NamedTimeZone, generation dataGeneration: Int = 0
    ) async throws(StorageError) -> GenerationRun {
        try await write(generation: dataGeneration) { db in
            let generation = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone)
            let (items, schedules) = try Self.itemsAndSchedules(db)
            let dates = generation.candidateDates
            // The join starts at the slots, so each slot reads only its rows of these dates through the key index.
            let stored = try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.*,
                        EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id) AS hasEvents
                    FROM scheduleSlot CROSS JOIN occurrence
                        ON occurrence.slotID = scheduleSlot.id AND occurrence.plannedDate BETWEEN ? AND ?
                    ORDER BY occurrence.rowid
                    """,
                arguments: [try dates[0].text, try dates[dates.count - 1].text]
            ).map { row in
                StoredOccurrence(occurrence: try Self.decodeOccurrence(row), hasEvents: try row.decode(forColumn: "hasEvents"))
            }
            let outcome = generation.outcome(items: items, schedules: schedules, stored: stored)
            for occurrence in outcome.created {
                try Self.insert(occurrence, db)
            }
            for occurrence in outcome.replanned {
                try Self.replan(occurrence, db)
            }
            let planZones = schedules.flatMap(\.versions).map { version in
                switch version.timeZonePolicy {
                case .fixed(let zone): zone
                case .followsDevice: deviceTimeZone
                }
            }
            return GenerationRun(occurrences: outcome.occurrences, planZones: Set(planZones))
        }
    }

    /// Gives a stored occurrence another planned time, time zone, and schedule version. The ID and the key stay.
    /// An occurrence with an intake event does not change: the write is `StorageError.conflict`.
    /// The domain already leaves such an occurrence out, so this condition is a second guard (spec 7.2).
    static func replan(_ occurrence: Occurrence, _ db: Database) throws {
        try db.execute(
            sql: """
                UPDATE occurrence SET plannedTime = ?, timeZone = ?, scheduleVersionID = ?
                WHERE id = ? AND slotID = ? AND plannedDate = ?
                    AND NOT EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                """,
            arguments: [
                occurrence.plannedTime.text, occurrence.timeZone.identifier, occurrence.scheduleVersionID.text,
                occurrence.id.text, occurrence.slotID.text, try occurrence.plannedDate.text,
            ]
        )
        guard db.changesCount == 1 else { throw StorageError.conflict }
    }
}
