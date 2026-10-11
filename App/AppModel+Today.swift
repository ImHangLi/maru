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
/// Today, the reminder choice, and the history use it, and no navigation clears it (D014).
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
    /// The finished parts of the day that show one line. Set when the page shows after a launch or a return,
    /// by a tap on a title, and a short time after the record that finishes a part (D012, D028).
    var foldedParts: Set<DayPart> = []
    /// The title of the current part of the day has the tint for a few seconds after a launch or a return (D020).
    var highlightsCurrentPart = false
    /// Counts the commits, for the success haptic. It changes only after a commit (spec 7.2).
    var commitCount = 0
    var failure: TodayFailure?
    /// The next content that shows comes from a launch or a return to the app.
    var isReturning = true
    var highlightRun = 0
    /// Refreshes Today when the day changes while the app stays in front.
    var dayChange: Task<Void, Never>?
    /// The rows of a tapped reminder. Today scrolls to their card and keeps it open until the app leaves the front,
    /// or until the user records every row of it (D028).
    var focus: TodayFocus?
    /// The pages over Today. A row action of the context menu opens the detail of its item here (D028).
    var path: [ItemID] = []
    /// The candidates of a tapped reminder that the user must choose from (spec 8.3).
    var choice: ReminderChoice?
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

    /// "Record All" of a part of the day: every open row of the part as taken, in one transaction (D021).
    func recordAll(_ group: TodaySnapshot.Group) {
        let open = group.openEntries.filter { today.pending[$0.id] == nil }
        guard !open.isEmpty else { return }
        commit(open.map { event(for: $0, .taken) })
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

    /// Every row of the part is done. Only a finished part folds.
    func isFinished(_ group: TodaySnapshot.Group) -> Bool {
        group.entries.allSatisfy(isDone)
    }

    /// Only a finished part opens and folds.
    func toggleFold(_ group: TodaySnapshot.Group) {
        guard isFinished(group) else { return }
        if today.foldedParts.contains(group.part) {
            today.foldedParts.remove(group.part)
        } else {
            today.foldedParts.insert(group.part)
        }
    }

    func isFolded(_ group: TodaySnapshot.Group) -> Bool {
        isFinished(group) && today.foldedParts.contains(group.part)
    }

    /// The pause between the record that finishes a part and its fold, so the user sees the last check first.
    private static let foldDelay = Duration.milliseconds(700)

    private var finishedParts: Set<DayPart> {
        guard case let .loaded(snapshot) = content, let day = snapshot.today else { return [] }
        return Set(day.groups.filter(isFinished).map(\.part))
    }

    /// A part that a record finished folds after a short pause, with the same animation as a tap on its title.
    /// It must not fold at once: a part that was folded earlier, for example on another day, opens first (D028).
    private func foldParts(finishedSince before: Set<DayPart>) {
        let parts = finishedParts.subtracting(before)
        guard !parts.isEmpty else { return }
        today.foldedParts.subtract(parts)
        Task { [weak self] in
            try? await Task.sleep(for: Self.foldDelay)
            guard let self else { return }
            // An undo in the pause leaves the part open.
            let ready = parts.intersection(finishedParts)
            guard !ready.isEmpty else { return }
            withMotion(.layout) { today.foldedParts.formUnion(ready) }
        }
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
    func commitAndWait(_ events: [PendingEvent], generation: Int) async -> Bool {
        guard generation == dataGeneration, begin(events) else { return false }
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
    private func begin(_ events: [PendingEvent]) -> Bool {
        let ids = Set(events.map(\.event.occurrenceID))
        // A restore replaces the data while it runs (D040).
        guard !transfer.isRestoring, !events.isEmpty, today.inFlight.isDisjoint(with: ids) else { return false }
        // An occurrence with an event that the store did not confirm takes only that same event again (D014).
        guard events.allSatisfy({ event in today.pending[event.event.occurrenceID].map { $0 == event } ?? true }) else {
            return false
        }
        today.inFlight.formUnion(ids)
        for id in ids {
            today.confirmed[id] = shownRecord(of: id)
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

    /// The records that a new read must not change: the last confirmed record of each occurrence with a running
    /// transaction. Today and the reminder choice put them in place of what they read (spec 7.2, T19).
    var heldRecords: [OccurrenceRecord] { Array(today.confirmed.values) }

    /// The record that the page shows for an occurrence: on Today, in the reminder choice, or in the history.
    private func shownRecord(of id: OccurrenceID) -> OccurrenceRecord? {
        if case let .loaded(snapshot) = content, let entry = snapshot.today?.entries.first(where: { $0.id == id }) {
            return entry.record
        }
        if let candidate = today.choice?.candidates.first(where: { $0.occurrence?.id == id }) {
            return candidate.record
        }
        return history.days?.lazy.flatMap(\.doses).first { $0.occurrence.id == id }?.record
    }

    private func didCommit(_ records: [OccurrenceRecord], backfilled: [Occurrence] = []) {
        let finishedBefore = finishedParts
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
        today.choice?.apply(records)
        historyDidCommit(records)
        today.commitCount += 1
        foldParts(finishedSince: finishedBefore)
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
        Task.detached { [store] in
            _ = try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
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
    ///
    /// - Parameter replacesToday: The page showed a day before this content. A part that folds on a return
    ///   then uses the layout motion, like a tap on its title. At a launch the page shows folded (D030).
    func todayDidShow(replacesToday: Bool) {
        guard case let .loaded(snapshot) = content, let day = snapshot.today else { return }
        if today.isReturning {
            today.isReturning = false
            let folded = Set(day.groups.filter(isFinished).map(\.part)).subtracting(focusedParts(of: day))
            withMotion(replacesToday ? .layout : nil) { today.foldedParts = folded }
            highlightCurrentPart()
        }
        // The page stays in front over midnight: read again at the next midnight of a zone of the content.
        today.dayChange?.cancel()
        let interval = day.expiresAt.timeIntervalSinceNow + 1
        today.dayChange = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(interval, 1)))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func highlightCurrentPart() {
        today.highlightRun += 1
        let run = today.highlightRun
        today.highlightsCurrentPart = true
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, today.highlightRun == run else { return }
            today.highlightsCurrentPart = false
        }
    }
}
