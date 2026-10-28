import Foundation
import MaruCore
import MaruDatabase

/// One as-needed event and its occurrence. A retry sends this same pair again (D014).
struct AsNeededEvent: Equatable, Sendable {
    let event: IntakeEvent
    let occurrence: AsNeededOccurrence
}

/// Why an as-needed record gave no success. The card shows it in an alert.
struct AsNeededFailure: Identifiable, Equatable {
    /// The same two cases as on Today: nothing is confirmed, "Try Again" sends the same pair again, or the stored
    /// state is not the one that the card showed and the page reads again.
    typealias Kind = TodayFailure.Kind

    let id = UUID()
    let kind: Kind
    /// The pair that "Try Again" sends. `nil` for `changed`.
    let pending: AsNeededEvent?
}

/// An as-needed event that the store did not confirm. Until a retry of the same pair succeeds, the card
/// shows the dose as the store last confirmed it, also when a read leaves the dose out (D014, T19).
struct UnconfirmedAsNeeded: Equatable, Sendable {
    let pending: AsNeededEvent
    /// The dose that the card showed before the event. `nil` for a new dose: the card does not show it.
    let confirmed: AsNeededCard.Dose?
    /// The look of the item, so its row stays when a read leaves the item out.
    let look: TodaySnapshot.ItemLook
}

/// The state of the "As needed" card that is not in the store.
struct AsNeededState {
    /// The events that the store did not confirm, by dose. A dose takes only its own event again (D014).
    var unconfirmed: [OccurrenceID: UnconfirmedAsNeeded] = [:]
    /// The doses with a record transaction that runs, and the dose that the card showed before it.
    /// A read in that time can show the new event before a success, so the card shows the held dose.
    /// The value is `nil` for a new dose: the card does not show it before the commit (spec 7.2).
    var inFlight: [OccurrenceID: AsNeededCard.Dose?] = [:]
    /// The item look of each dose in `inFlight`, so the card can show a held dose also when the read
    /// left out its whole item row.
    var inFlightLooks: [OccurrenceID: TodaySnapshot.ItemLook] = [:]
    /// The items with a new dose in `inFlight`. A second tap on their record button does nothing (T18).
    var recordingItems: Set<ItemID> = []
    var failure: AsNeededFailure?

    /// The new dose of an item that the store did not confirm. The record button offers only its retry.
    func newDose(of itemID: ItemID) -> AsNeededEvent? {
        unconfirmed.values.first { $0.confirmed == nil && $0.pending.occurrence.itemID == itemID }?.pending
    }

    /// The correction of a shown dose that the store did not confirm.
    func correction(of id: OccurrenceID) -> AsNeededEvent? {
        unconfirmed[id].flatMap { $0.confirmed == nil ? nil : $0.pending }
    }

    /// The dose that the card shows in place of the read one. `.some(nil)` hides the dose.
    func heldDose(_ id: OccurrenceID) -> AsNeededCard.Dose?? {
        if let entry = unconfirmed[id] { return .some(entry.confirmed) }
        return inFlight[id]
    }
}

extension AppModel {
    // MARK: Operations of the card

    /// The record button of an item: a new dose at the time of the tap.
    func recordAsNeeded(_ row: AsNeededCard.Row) {
        if let pending = today.asNeeded.newDose(of: row.itemID) {
            commitAsNeeded(pending, look: row.look)
            return
        }
        // A second tap while the first one runs does nothing, so one tap gives one dose (T18).
        guard row.canRecord, !isRecordingAsNeeded(row),
              let deviceTimeZone = NamedTimeZone(device: .current, at: .now) else { return }
        let now = Date()
        // The dose copies the usual amount of the item, so a later change of the amount does not rewrite it (D091).
        let occurrence = AsNeededOccurrence(itemID: row.itemID, at: now, in: deviceTimeZone, dose: row.amount)
        commitAsNeeded(
            AsNeededEvent(
                event: IntakeEvent(occurrenceID: occurrence.id, action: .taken, occurredAt: now, recordedAt: now, source: .app),
                occurrence: occurrence
            ),
            look: row.look
        )
    }

    func undo(_ dose: AsNeededCard.Dose, in row: AsNeededCard.Row) {
        commitAsNeeded(event(for: dose, .undo), look: row.look)
    }

    /// Replaces the taken record with one at the time that the user chose. The history keeps both (T20).
    func changeTime(_ dose: AsNeededCard.Dose, in row: AsNeededCard.Row, to time: Date) {
        commitAsNeeded(event(for: dose, .taken, at: time), look: row.look)
    }

    /// Sends the same correction again after a failure. A new event is not made (D014).
    func retry(_ dose: AsNeededCard.Dose) {
        guard let entry = today.asNeeded.unconfirmed[dose.id], entry.confirmed != nil else { return }
        commitAsNeeded(entry.pending, look: entry.look)
    }

    func retry(_ failure: AsNeededFailure) {
        today.asNeeded.failure = nil
        history.asNeededFailure = nil
        guard let pending = failure.pending, let entry = today.asNeeded.unconfirmed[pending.occurrence.id] else { return }
        commitAsNeeded(pending, look: entry.look)
    }

    func isRecordingAsNeeded(_ row: AsNeededCard.Row) -> Bool {
        today.asNeeded.recordingItems.contains(row.itemID)
    }

    /// The rows that the card shows. A new dose with no success yet does not show. A dose with a correction
    /// that runs or failed shows as the store last confirmed it, also when the read left it out, for example
    /// after an undo that committed and gave no success (spec 7.2, T19). A dose of another day does not show.
    func shownRows(of card: AsNeededCard) -> [AsNeededCard.Row] {
        let state = today.asNeeded
        var rows = card.rows.map { row in
            var row = row
            row.doses = row.doses.compactMap { dose in
                if let held = state.heldDose(dose.id) { return held }
                return dose
            }
            return row
        }
        let read = Set(card.rows.flatMap(\.doses).map(\.id))
        var missing: [(dose: AsNeededCard.Dose, look: TodaySnapshot.ItemLook?)] = []
        for (id, entry) in state.unconfirmed where !read.contains(id) {
            if let dose = entry.confirmed { missing.append((dose, entry.look)) }
        }
        for case let (id, dose?) in state.inFlight where !read.contains(id) && state.unconfirmed[id] == nil {
            missing.append((dose, state.inFlightLooks[id]))
        }
        let sorted = missing
            .filter { $0.dose.occurrence.plannedDate == card.date }
            .sorted { ($0.dose.record.events.first?.recordedAt ?? .distantPast) < ($1.dose.record.events.first?.recordedAt ?? .distantPast) }
        for (dose, look) in sorted {
            if let index = rows.firstIndex(where: { $0.itemID == dose.occurrence.itemID }) {
                rows[index].doses.append(dose)
            } else if let look {
                rows.append(AsNeededCard.Row(itemID: dose.occurrence.itemID, look: look, canRecord: false, doses: [dose]))
            }
        }
        // A new dose with no success keeps the row of its item, so its retry button stays (D014).
        for entry in state.unconfirmed.values where entry.confirmed == nil && entry.pending.occurrence.plannedDate == card.date {
            let itemID = entry.pending.occurrence.itemID
            if !rows.contains(where: { $0.itemID == itemID }) {
                rows.append(AsNeededCard.Row(itemID: itemID, look: entry.look, canRecord: false, doses: []))
            }
        }
        return rows
    }

    // MARK: Record transaction

    func event(for dose: AsNeededCard.Dose, _ action: IntakeAction, at time: Date? = nil) -> AsNeededEvent {
        let now = Date()
        return AsNeededEvent(
            event: IntakeEvent(
                occurrenceID: dose.id,
                action: action,
                occurredAt: time ?? now,
                recordedAt: now,
                source: .app,
                supersedes: dose.record.events.last?.id
            ),
            occurrence: dose.occurrence
        )
    }

    /// Runs the record transaction. The card and the history change only after the commit (spec 7.2, T19).
    func commitAsNeeded(_ pending: AsNeededEvent, look: TodaySnapshot.ItemLook) {
        let id = pending.occurrence.id
        let itemID = pending.occurrence.itemID
        // A restore replaces the data while it runs (D040).
        guard !transfer.isRestoring, !today.asNeeded.inFlight.keys.contains(id) else { return }
        // A dose with an event that the store did not confirm takes only that same event again (D014).
        if let stored = today.asNeeded.unconfirmed[id], stored.pending != pending { return }
        // Only the first event of a dose revises nothing. A correction always revises the shown event.
        let isNew = pending.event.supersedes == nil
        let held = isNew ? nil : (today.asNeeded.unconfirmed[id]?.confirmed ?? shownDose(id))
        today.asNeeded.inFlight[id] = .some(held)
        today.asNeeded.inFlightLooks[id] = look
        if isNew { today.asNeeded.recordingItems.insert(itemID) }
        let generation = dataGeneration
        Task {
            do throws(RecordFailure) {
                let record = try await store.recordAsNeeded(
                    pending.event, occurrence: pending.occurrence, generation: generation
                )
                // A restore replaced the rows of this dose. The model forgot it.
                guard generation == dataGeneration else { return }
                didCommitAsNeeded(record, pending)
            } catch {
                guard generation == dataGeneration else { return }
                didFailAsNeeded(UnconfirmedAsNeeded(pending: pending, confirmed: held, look: look), error)
            }
            today.asNeeded.inFlight[id] = nil
            today.asNeeded.inFlightLooks[id] = nil
            if isNew { today.asNeeded.recordingItems.remove(itemID) }
        }
    }

    /// A dose on Today or in the history, or `nil` for a dose that neither page has.
    private func shownDose(_ id: OccurrenceID) -> AsNeededCard.Dose? {
        if case let .loaded(snapshot) = content, let card = snapshot.today?.asNeeded,
           let dose = card.rows.lazy.flatMap(\.doses).first(where: { $0.id == id }) {
            return dose
        }
        return history.days?.lazy.flatMap(\.asNeeded).first { $0.occurrence.id == id }.map(AsNeededCard.Dose.init)
    }

    private func didCommitAsNeeded(_ record: OccurrenceRecord, _ pending: AsNeededEvent) {
        noteRecords([record])
        proRecordsDidCommit([record])
        forget(pending)
        historyDidCommitAsNeeded(record, of: pending.occurrence)
        // A retry can succeed after midnight, when the content shows another day. Only a dose of the shown
        // day goes into the card. The read shows the stored state of the other day.
        if case var .loaded(snapshot) = content, snapshot.today?.date == pending.occurrence.plannedDate {
            snapshot.today?.asNeeded.apply(record, of: pending.occurrence)
            content = .loaded(snapshot)
            if record.status == .taken {
                // A read that started before the commit can show the old state, so read again after it.
                refreshAfterRunningRead()
            } else {
                // An undo or a skip can remove the newest taken dose. Only the store has the one before it (D091).
                refresh()
            }
        } else {
            refresh()
        }
        today.commitCount += 1
        reloadWidgets()
        // An as-needed dose has no reminder, so the notification queue does not change (D021).
    }

    private func didFailAsNeeded(_ entry: UnconfirmedAsNeeded, _ failure: RecordFailure) {
        let pending = entry.pending
        // The open history shows the alert. Today is under it.
        func show(_ failure: AsNeededFailure) {
            if history.isOpen { history.asNeededFailure = failure } else { today.asNeeded.failure = failure }
        }
        switch failure {
        case .storage(.conflict):
            // The ID or the item does not agree with the store, so the same pair can never succeed.
            forget(pending)
            show(AsNeededFailure(kind: .changed, pending: nil))
            refreshAfterAsNeededChange()
        case let .storage(error):
            // The event can be stored already, after `unavailable`. Keep it, and send the same one again (D014).
            today.asNeeded.unconfirmed[pending.occurrence.id] = entry
            show(AsNeededFailure(kind: .notSaved(error), pending: pending))
        case .unknownOccurrence, .versionChanged, .ownerChanged, .rejected:
            // The store has another state than the card. Nothing was written. Show the stored state.
            forget(pending)
            show(AsNeededFailure(kind: .changed, pending: nil))
            refreshAfterAsNeededChange()
        case .replaced:
            // A restore replaced the data. Nothing was written, and the model forgets the old data next (D040).
            break
        }
    }

    private func refreshAfterAsNeededChange() {
        refresh()
        if history.isOpen { loadHistory() }
    }

    private func forget(_ pending: AsNeededEvent) {
        if today.asNeeded.unconfirmed[pending.occurrence.id]?.pending == pending {
            today.asNeeded.unconfirmed[pending.occurrence.id] = nil
        }
    }
}

extension AppStore {
    /// The record transaction of an as-needed dose (spec 7.2, D021).
    func recordAsNeeded(
        _ event: IntakeEvent, occurrence: AsNeededOccurrence, generation: Int
    ) async throws(RecordFailure) -> OccurrenceRecord {
        let store: LocalStore
        do throws(StorageError) {
            store = try open()
        } catch {
            throw .storage(error)
        }
        return try await store.recordAsNeeded(event, occurrence: occurrence, generation: generation)
    }
}
