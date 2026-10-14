import Foundation
import MaruCore
import MaruDatabase
import SwiftUI

/// An event that the store did not confirm. The row offers only a retry of this same event (D014).
struct PendingEvent: Equatable, Sendable {
    let event: IntakeEvent
    let scheduleVersionID: ScheduleVersionID
    /// The occurrence that a backfill of the history stores with the event, for a past dose that no generation
    /// run stored. A retry sends this same occurrence (D014).
    var backfill: Occurrence?
    /// The record must still be in the plan of now: an active item, a slot of the plan, the planned schedule
    /// version, and a dose of today. The widget and the Watch set it, because their rows can be old (D048, D071).
    var requiresCurrentPlan = false
    /// The restore epoch that the widget read. The store checks it in the record transaction (D048).
    var restoreEpoch: Int?
}

/// Why a record on Today gave no success. The page shows it in an alert.
struct TodayFailure: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Nothing is confirmed. The same events go again with "Try Again".
        case notSaved(StorageError)
        /// The stored state is not the one that the page showed. The page reads again.
        case changed
    }

    let id = UUID()
    let kind: Kind
    /// The events that "Try Again" sends again. Empty for `changed`.
    let events: [PendingEvent]
}

/// The state of the Today page that is not in the store.
///
/// `pending`, `inFlight`, `confirmed`, and `backfills` are the one list of unconfirmed events of the app.
/// Today and the history use it, and no navigation clears it (D014).
struct TodayState {
    /// The events that failed, by occurrence. A row with one shows "not saved" until a retry succeeds (D014).
    var pending: [OccurrenceID: PendingEvent] = [:]
    /// The occurrence of each backfill that runs or failed, by slot and date. A new read of the history gives
    /// a dose that is not stored a new occurrence value, so the history puts this one in its place.
    var backfills: [OccurrenceKey: Occurrence] = [:]
    /// The occurrences with a record transaction that runs. A second tap on them does nothing (T18).
    var inFlight: Set<OccurrenceID> = []
    /// The last confirmed record of each occurrence in `inFlight`. The store can commit before the transaction
    /// ends, so a read in that time can show the new event before a success. The page shows this record
    /// until the transaction ends (spec 7.2, D014, T19).
    var confirmed: [OccurrenceID: OccurrenceRecord] = [:]
    /// Counts the commits, for the success haptic. It changes only after a commit (spec 7.2).
    var commitCount = 0
    var failure: TodayFailure?
    /// Refreshes Today when the day changes while the app stays in front.
    var dayChange: Task<Void, Never>?
    /// The rows of a tapped reminder. Today scrolls to their card until the app leaves the front (D028).
    var focus: TodayFocus?
    /// The pages over Today. A row action of the context menu opens the detail of its item here (D028).
    var path: [ItemID] = []
    /// A tapped reminder that the app could not read while the iPhone was locked (T40).
    var lockedTap: DeliveredReminder?
    /// The state of the "As needed" card. See `AppModel+AsNeeded.swift`.
    var asNeeded = AsNeededState()
}

extension AppModel {
    private typealias Entry = TodaySnapshot.Entry

    // MARK: Operations of the rows

    /// The record circle of an open row: taken now.
    func record(_ entry: TodaySnapshot.Entry) {
        commit([event(for: entry, .taken)])
    }

    func undo(_ entry: TodaySnapshot.Entry) {
        commit([event(for: entry, .undo)])
    }

    func markSkipped(_ entry: TodaySnapshot.Entry) {
        commit([event(for: entry, .skipped)])
    }

    func markTaken(_ entry: TodaySnapshot.Entry) {
        commit([event(for: entry, .taken)])
    }

    /// Taken at the time that the user chose. "Change Time…" replaces the taken record, and the history keeps
    /// both (T20). "Taken Earlier…" records an open row with that time (D033).
    func changeTime(_ entry: TodaySnapshot.Entry, to time: Date) {
        commit([event(for: entry, .taken, at: time)])
    }

    /// Sends the same event again after a failure. A new event is not made (D014).
    func retry(_ entry: TodaySnapshot.Entry) {
        guard let pending = today.pending[entry.id] else { return }
        commit([pending])
    }

    func retry(_ failure: TodayFailure) {
        today.failure = nil
        commit(failure.events)
    }

    /// A row with an event that the store did not confirm is not done, also when a read shows the stored event.
    /// Only a retry that succeeds makes it done (D014, T19).
    func isDone(_ entry: TodaySnapshot.Entry) -> Bool {
        !entry.isOpen && today.pending[entry.id] == nil
    }

    // MARK: Record transaction

    /// A new event revises the last event of the row, also after an undo.
    private func event(for entry: Entry, _ action: IntakeAction, at time: Date? = nil) -> PendingEvent {
        let now = Date()
        return PendingEvent(
            event: IntakeEvent(
                occurrenceID: entry.id,
                action: action,
                occurredAt: time ?? now,
                recordedAt: now,
                source: .app,
                supersedes: entry.record.events.last?.id
            ),
            scheduleVersionID: entry.occurrence.scheduleVersionID
        )
    }

    /// Runs the record transaction. The page changes only after the commit (spec 7.2, T19).
    func commit(_ events: [PendingEvent]) {
        guard begin(events) else { return }
        let generation = dataGeneration
        Task { await run(events, generation: generation) }
    }

    /// The same transaction for a caller that waits for its end, for example the "Taken" action of a reminder (D034).
    /// `generation` is the generation of the data that the caller read the events from. `true` only after the commit.
    /// `confirmed` is the record that the caller read for an occurrence that no page shows, for example on a
    /// background launch. A read during the transaction shows it in place of a commit that is not flushed.
    func commitAndWait(
        _ events: [PendingEvent], generation: Int, confirmed: [OccurrenceID: OccurrenceRecord] = [:]
    ) async -> Bool {
        guard generation == dataGeneration, begin(events, confirmed: confirmed) else { return false }
        return await run(events, generation: generation)
    }

    /// The banner of Today and of the history: every event that the store did not confirm, also of a dose
    /// that no page shows now, for example after an undo of an archived item or an as-needed dose of
    /// yesterday (D014, T19).
    var unsavedCount: Int { today.pending.count + today.asNeeded.unconfirmed.count }

    /// A retry of the banner is running.
    var isRetryingUnsaved: Bool {
        unsavedCount > 0
            && today.pending.keys.allSatisfy(today.inFlight.contains)
            && today.asNeeded.unconfirmed.keys.allSatisfy(today.asNeeded.inFlight.keys.contains)
    }

    /// Sends each unconfirmed event again, the same event, in the order that the user made them (D014).
    /// Each one is its own transaction, so one that the store rejects does not stop the others.
    /// An as-needed event goes again with its own occurrence.
    func retryUnsaved() {
        today.failure = nil
        history.failure = nil
        today.asNeeded.failure = nil
        history.asNeededFailure = nil
        let events = today.pending.values
            .sorted { $0.event.recordedAt < $1.event.recordedAt }
            .filter { begin([$0]) }
        let generation = dataGeneration
        Task {
            for event in events {
                await run([event], generation: generation)
            }
        }
        for entry in today.asNeeded.unconfirmed.values.sorted(by: { $0.pending.event.recordedAt < $1.pending.event.recordedAt }) {
            commitAsNeeded(entry.pending, look: entry.look)
        }
    }

    /// Marks the events as running. False when one of them runs already, or is not the same event as the
    /// unconfirmed one of its occurrence.
    private func begin(_ events: [PendingEvent], confirmed: [OccurrenceID: OccurrenceRecord] = [:]) -> Bool {
        let ids = Set(events.map(\.event.occurrenceID))
        // A restore replaces the data while it runs (D040).
        guard !transfer.isRestoring, !events.isEmpty, today.inFlight.isDisjoint(with: ids) else { return false }
        // An occurrence with an event that the store did not confirm takes only that same event again (D014).
        guard events.allSatisfy({ event in today.pending[event.event.occurrenceID].map { $0 == event } ?? true }) else {
            return false
        }
        today.inFlight.formUnion(ids)
        for id in ids {
            today.confirmed[id] = confirmed[id] ?? shownRecord(of: id)
        }
        for occurrence in events.compactMap(\.backfill) {
            today.backfills[occurrence.key] = occurrence
        }
        return true
    }

    /// Returns `true` after the commit. The store refuses the events when a restore changed the generation
    /// of the data after the model read them (D040).
    @discardableResult
    private func run(_ events: [PendingEvent], generation: Int) async -> Bool {
        let ids = Set(events.map(\.event.occurrenceID))
        var committed = false
        do throws(RecordFailure) {
            // A backfill is one event, with its occurrence in the same transaction.
            let records = if events.count == 1, let occurrence = events[0].backfill {
                [try await store.recordBackfill(events[0].event, occurrence: occurrence, generation: generation)]
            } else if events.contains(where: \.requiresCurrentPlan) {
                try await recordInCurrentPlan(events, generation: generation)
            } else {
                try await store.record(events.map { ($0.event, $0.scheduleVersionID) }, generation: generation)
            }
            // A restore replaced the rows of these events. The model forgot them.
            guard generation == dataGeneration else { return false }
            didCommit(records, backfilled: events.compactMap(\.backfill))
            committed = true
        } catch {
            guard generation == dataGeneration else { return false }
            didFail(events, error)
        }
        today.inFlight.subtract(ids)
        for id in ids {
            today.confirmed[id] = nil
        }
        return committed
    }

    /// The record of the widget: the store also checks the plan of now in the transaction (D048).
    /// The store reads the clock and the device time zone in the transaction, not before the wait for the writer.
    private func recordInCurrentPlan(_ events: [PendingEvent], generation: Int) async throws(RecordFailure) -> [OccurrenceRecord] {
        try await store.record(
            events.map { ($0.event, $0.scheduleVersionID) },
            generation: generation,
            currentPlan: {
                let now = Date()
                return NamedTimeZone(device: .current, at: now).map { OccurrenceGeneration(now: now, deviceTimeZone: $0) }
            },
            restoreEpoch: events.first?.restoreEpoch
        )
    }

    /// The records that a new read must not change: the last confirmed record of each occurrence with a running
    /// transaction. Today puts them in place of what they read (spec 7.2, T19).
    var heldRecords: [OccurrenceRecord] { Array(today.confirmed.values) }

    /// The record that the page shows for an occurrence: on Today or in the history.
    private func shownRecord(of id: OccurrenceID) -> OccurrenceRecord? {
        if case let .loaded(snapshot) = content, let entry = snapshot.today?.entries.first(where: { $0.id == id }) {
            return entry.record
        }
        return history.days?.lazy.flatMap(\.doses).first { $0.occurrence.id == id }?.record
    }

    private func didCommit(_ records: [OccurrenceRecord], backfilled: [Occurrence] = []) {
        noteRecords(records)
        for record in records {
            today.pending[record.occurrenceID] = nil
        }
        for occurrence in backfilled {
            today.backfills[occurrence.key] = nil
        }
        if case var .loaded(snapshot) = content, snapshot.today != nil {
            snapshot.today?.apply(records)
            content = .loaded(snapshot)
        }
        sendWatchDay()
        historyDidCommit(records)
        today.commitCount += 1
        if backfilled.isEmpty {
            // A read that started before the commit can show the old state, so read again after it.
            refreshAfterRunningRead()
        } else {
            // Today can show a dose of another day, for example of yesterday in a fixed zone (spec 8.5).
            refresh()
        }
        refreshReminders()
    }

    /// A record, a skip, an undo, or a new time changes which slot times are open. The reminders and the follow-ups
    /// depend on the records, so both run again. A dose that is recorded before its time leaves the reminder
    /// of that time, and an undo before the time brings it back (spec 8.2, D047).
    func refreshReminders() {
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        // The system can suspend the app after a record. Hold background time until the run ends (D083).
        let assertion = BackgroundAssertion(name: "Reminders")
        Task.detached { [store] in
            _ = try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
            await assertion.end()
        }
    }

    private func didFail(_ events: [PendingEvent], _ failure: RecordFailure) {
        // The open history shows the alert. Today is under it.
        func show(_ failure: TodayFailure) {
            if history.isOpen { history.failure = failure } else { today.failure = failure }
        }
        switch failure {
        case .storage(.conflict) where events.contains(where: { $0.backfill != nil }):
            // A generation run stored this dose first. Nothing was written. Show the stored dose.
            didChange(events)
            show(TodayFailure(kind: .changed, events: []))
        case let .storage(error):
            // The event can be stored already, after `unavailable`. Keep it, and send the same one again (D014).
            for pending in events {
                today.pending[pending.event.occurrenceID] = pending
            }
            show(TodayFailure(kind: .notSaved(error), events: events))
        case .unknownOccurrence, .versionChanged, .rejected:
            // The store has another state than the page. Nothing was written. Show the stored state.
            didChange(events)
            show(TodayFailure(kind: .changed, events: []))
        case .replaced:
            // A restore replaced the data. Nothing was written, and the model forgets the old data next (D040).
            break
        }
    }

    private func didChange(_ events: [PendingEvent]) {
        for pending in events {
            today.pending[pending.event.occurrenceID] = nil
            if let occurrence = pending.backfill { today.backfills[occurrence.key] = nil }
        }
        refresh()
        if history.isOpen {
            loadHistory()
            loadHistoryGraph()
        }
    }

    // MARK: Launch, return, and day change

    /// Runs each time new content shows.
    func todayDidShow() {
        guard case let .loaded(snapshot) = content, let day = snapshot.today else { return }
        // The page stays in front over midnight: read again at the next midnight of a zone of the content.
        today.dayChange?.cancel()
        let interval = day.expiresAt.timeIntervalSinceNow + 1
        today.dayChange = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(interval, 1)))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
