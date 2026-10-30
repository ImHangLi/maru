import Foundation
import GRDB
import MaruCore

/// What an action of a reminder did to one dose (spec 8.3, D034, D090).
public enum DoseOutcome: Hashable, Sendable {
    /// The dose was open, and the action wrote this event. `record` is the record after the event.
    case recorded(event: IntakeEvent, scheduleVersionID: ScheduleVersionID, record: OccurrenceRecord)
    /// The dose had a taken or a skipped state already, and the action left it as it was. A skip is a choice of the user.
    /// "Take All" does not replace it, and "Skip All" does not replace a taken dose (D034).
    case unchanged(OccurrenceStatus)
    /// The dose failed a check: it is not in the plan of now with the schedule version of the request, its date is not today,
    /// or its occurrence is not stored. Nothing was written for it.
    case notRecorded
}

/// What one action of a reminder did to the doses that the reminder names (D090).
public struct ReminderActionResult: Sendable {
    /// How many doses the reminder names.
    public let named: Int
    /// The outcome of each dose that the plan of now still has with the version of the request, with its key.
    public let doses: [(key: OccurrenceKey, outcome: DoseOutcome)]
    /// The storage medium has the commit. `false` after a failed flush: the events are stored, and the caller sends the same
    /// events again and shows no success until that works (spec 7.2, D014, `RecordFailure.storage`).
    public let isFlushed: Bool

    /// The events that this action wrote, with the record after each event.
    public var recorded: [(event: IntakeEvent, scheduleVersionID: ScheduleVersionID, record: OccurrenceRecord)] {
        doses.compactMap {
            if case let .recorded(event, version, record) = $0.outcome { (event, version, record) } else { nil }
        }
    }

    /// The doses that were open, and that the action left as they were.
    public var unchangedCount: Int {
        doses.filter { if case .unchanged = $0.outcome { true } else { false } }.count
    }

    /// The named doses that the action did not record and did not find closed.
    public var notRecordedCount: Int {
        max(0, named - recorded.count - unchangedCount)
    }
}

extension LocalStore {
    /// The one command of every action of a reminder that writes a record: "Taken", "Skip", "Take All", and "Skip All" of a
    /// notification, and the "Taken" button of an alarm (spec 8.3, D034, D090).
    ///
    /// `ReminderTapResolver.actionDoses` gives the doses that the reminder names. One transaction then checks each dose and
    /// appends the event only for a dose that is open. A dose that has a record already stays as it is. A dose that fails a check is
    /// not written, and the other doses are: a change to one dose between the read and the write does not undo the others.
    /// The checks of each dose, in the transaction:
    /// - The stored occurrence exists, and its date is today in its own time zone. For a follow-up it can also be the day
    ///   before, until `FollowUpPlan.latestTime` (D039).
    /// - It has the schedule version that the plan of now has for the dose, for every action (D089). A follow-up with the ID of one item
    ///   also has the version that the request was made for (D034).
    /// A generation run comes first, so a launch by the action finds the occurrences of yesterday and today.
    ///
    /// The call returns after the commit and the flush. On an error nothing is written, with the exception of `RecordFailure.storage(.unavailable)`
    /// after the commit. A failed flush after the commit is `isFlushed == false` and not an error, so the caller keeps the events.
    ///
    /// - Parameters:
    ///   - action: `taken` or `skipped`. An undo records nothing.
    ///   - observedTimeZone: What `DefaultsTimeZoneRecord.load()` returns.
    ///   - generation: The generation of the data that the caller read. See `checkedWrite`.
    ///   - sync: For tests. See `flush`.
    public func recordOpenDoses(
        for reminder: DeliveredReminder,
        action: IntakeAction,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        observedTimeZone: ObservedTimeZone?,
        generation: Int = 0
    ) async throws(RecordFailure) -> ReminderActionResult {
        try await recordOpenDoses(
            for: reminder, action: action, at: now, deviceTimeZone: deviceTimeZone, observedTimeZone: observedTimeZone,
            generation: generation, sync: Self.fullSync
        )
    }

    func recordOpenDoses(
        for reminder: DeliveredReminder,
        action: IntakeAction,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        observedTimeZone: ObservedTimeZone?,
        generation: Int,
        sync: @Sendable (Int32) -> Int32
    ) async throws(RecordFailure) -> ReminderActionResult {
        do {
            _ = try await generate(at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        } catch {
            throw error == .replaced ? .replaced : .storage(error)
        }
        let isFollowUp = reminder.userInfo[FollowUpRequest.plannedDateKey] != nil
        let result: (named: Int, doses: [(key: OccurrenceKey, outcome: DoseOutcome)])
        do {
            result = try await checkedWrite(generation: generation) { db in
                let (items, schedules) = try Self.itemsAndSchedules(db)
                let resolver = ReminderTapResolver(now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: observedTimeZone)
                let named = action == .undo ? ReminderActionDoses(named: 0, doses: []) : resolver.actionDoses(
                    of: reminder, items: items, schedules: schedules
                )
                let scheduleBySlot = Dictionary(schedules.flatMap { schedule in
                    schedule.slots.map { ($0.id, schedule.itemID) }
                }, uniquingKeysWith: { first, _ in first })
                let targets = items.filter { item in named.doses.contains { scheduleBySlot[$0.slotID] == item.id } }
                // Recheck the member rule in the transaction, also for old notification categories (D123).
                guard Set(targets.map(\.personID)).count <= 1 else { return (named.named, []) }
                var doses: [(key: OccurrenceKey, outcome: DoseOutcome)] = []
                for planned in named.doses {
                    guard let occurrence = try Row.fetchOne(
                        db,
                        sql: "SELECT * FROM occurrence WHERE slotID = ? AND plannedDate = ?",
                        arguments: [planned.slotID.text, planned.plannedDate.text]
                    ).map(Self.decodeOccurrence),
                        // A stored occurrence keeps its zone after travel, so its date can be another day there (spec 8.5).
                        // A follow-up can also stand for the dose of the day before, until a time after midnight (D039).
                        isFollowUp
                        ? FollowUpPlan.takesDose(on: occurrence.plannedDate, at: now, in: occurrence.timeZone)
                        : occurrence.plannedDate == LocalDate(now, in: occurrence.timeZone),
                        // The stored occurrence must have the schedule version that the plan of now has for the dose. An occurrence
                        // with an event keeps its old version after an undo and a plan edit. A record would then keep the old plan (D089).
                        occurrence.scheduleVersionID == planned.scheduleVersionID,
                        // A follow-up of one item also has the version that it was made for (D034).
                        reminder.userInfo[FollowUpRequest.scheduleVersionIDKey].map({ $0 == occurrence.scheduleVersionID.text }) ?? true
                    else {
                        doses.append((planned.key, .notRecorded))
                        continue
                    }
                    // The request was made, and the user saw it, under the owner of its time. After an owner change it records
                    // nothing, also when the system delivered a request that the reminder run did not replace yet (D123).
                    guard let item = targets.first(where: { $0.id == scheduleBySlot[planned.slotID] }),
                          !ReminderRequest.ownerChanged(item, after: reminder.userInfo[ReminderRequest.ownerChangedKey]),
                          item.ownerChangedAt.map({ $0 <= reminder.deliveredAt }) ?? true
                    else {
                        doses.append((planned.key, .notRecorded))
                        continue
                    }
                    let record = try Self.fetchCheckedRecord(db, occurrenceID: occurrence.id)
                    switch record.status {
                    case .unrecorded:
                        let event = record.nextEvent(action, at: now, source: .notificationAction)
                        let updated = try Self.append(event, db)
                        doses.append((planned.key, .recorded(event: event, scheduleVersionID: occurrence.scheduleVersionID, record: updated)))
                    case .taken, .skipped:
                        doses.append((planned.key, .unchanged(record.status)))
                    }
                }
                return (named.named, doses)
            }
        } catch {
            throw Self.recordFailure(error)
        }
        // The commit synced the WAL file. Wait until the drive wrote it to the storage medium (spec 7.2).
        let isFlushed = result.doses.isEmpty || Self.flush(walFile, sync: sync)
        return ReminderActionResult(named: result.named, doses: result.doses, isFlushed: isFlushed)
    }

    /// The group that a "Remind in 10 min" action stands for, and the time at which it comes again (D090). It writes nothing.
    /// `nil` when the reminder does not name a dose of today that the plan has, or when the follow-ups of the dose have stopped.
    public func snoozeEntry(
        for reminder: DeliveredReminder,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        observedTimeZone: ObservedTimeZone?
    ) async throws(StorageError) -> SnoozeEntry? {
        try await read { db in
            let (items, schedules) = try Self.itemsAndSchedules(db)
            return ReminderTapResolver(now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: observedTimeZone)
                .snoozeEntry(of: reminder, items: items, schedules: schedules)
        }
    }
}
