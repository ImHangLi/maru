import Foundation
import GRDB
import MaruCore

extension LocalStore: FollowUpSource {
    /// The follow-ups that the stored plan and records ask for (D021, D039). `FollowUpPlan` has the rules.
    /// Each item has its own setting (D079).
    ///
    /// One read gives the items, the schedules, and the stored occurrences with their state, so the plan is the state of one commit.
    /// An occurrence is closed when its projection row says taken or skipped. An undo deletes that row (spec 7.2).
    public func followUpPlan(
        privacy: ReminderPrivacy,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        alarmsRing: Bool
    ) async throws(StorageError) -> FollowUpPlan {
        try await read { db in
            let inputs = try Self.doseInputs(db, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy, alarmsRing: alarmsRing)
            return FollowUpPlan(
                reminders: inputs.reminders,
                items: inputs.items,
                schedules: inputs.schedules,
                stored: inputs.stored,
                closed: inputs.closed,
                now: now,
                deviceTimeZone: deviceTimeZone,
                privacy: privacy
            )
        }
    }

    /// What the plans of the follow-ups and of the alarms read, in one read transaction.
    struct DoseInputs {
        let items: [Item]
        let schedules: [Schedule]
        let stored: [StoredOccurrence]
        let closed: Set<OccurrenceKey>
        let reminders: ReminderPlan
    }

    static func doseInputs(
        _ db: Database, now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarmsRing: Bool
    ) throws -> DoseInputs {
        let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(Self.decodeItem)
        let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
            .compactMap { try Self.fetchSchedule(db, id: ScheduleID(text: $0)) }
        let dates = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone).candidateDates
        // The query of `generateOccurrences`, with the state of each occurrence. Records exist only for these dates.
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT occurrence.*,
                    EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id) AS hasEvents,
                    EXISTS (SELECT 1 FROM occurrenceState WHERE occurrenceID = occurrence.id) AS isClosed
                FROM scheduleSlot CROSS JOIN occurrence
                    ON occurrence.slotID = scheduleSlot.id AND occurrence.plannedDate BETWEEN ? AND ?
                ORDER BY occurrence.rowid
                """,
            arguments: [try dates[0].text, try dates[dates.count - 1].text]
        )
        var stored: [StoredOccurrence] = []
        var closed: Set<OccurrenceKey> = []
        for row in rows {
            let occurrence = try Self.decodeOccurrence(row)
            stored.append(StoredOccurrence(occurrence: occurrence, hasEvents: try row.decode(forColumn: "hasEvents")))
            if try row.decode(forColumn: "isClosed") as Bool { closed.insert(occurrence.key) }
        }
        return DoseInputs(
            items: items,
            schedules: schedules,
            stored: stored,
            closed: closed,
            reminders: ReminderPlan(
                items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy,
                closed: closed, alarmsRing: alarmsRing
            )
        )
    }
}

extension LocalStore: AlarmSource {
    /// The alarms that the stored plan and records ask for (D079). `AlarmPlan` has the rules.
    public func alarmPlan(
        privacy: ReminderPrivacy, at now: Date, deviceTimeZone: NamedTimeZone, alarmsRing: Bool
    ) async throws(StorageError) -> AlarmPlan {
        try await read { db in
            let inputs = try Self.doseInputs(db, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy, alarmsRing: alarmsRing)
            return AlarmPlan(
                reminders: inputs.reminders,
                items: inputs.items,
                schedules: inputs.schedules,
                stored: inputs.stored,
                closed: inputs.closed,
                now: now,
                deviceTimeZone: deviceTimeZone,
                privacy: privacy
            )
        }
    }
}
