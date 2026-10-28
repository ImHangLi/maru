import Foundation
import MaruCore
import MaruDatabase

/// One row of the timeline: one action of the user on one dose, or a planned dose of a past day with no record (D032).
struct HistoryEntry: Identifiable {
    enum Kind: Equatable { case taken, timeChanged, skipped, undone, noRecord, notSaved }
    enum Dose {
        case planned(HistoryDose)
        case asNeeded(HistoryAsNeededDose)
    }

    let id: AnyHashable
    let kind: Kind
    let dose: Dose
    /// `nil` for a dose with no record.
    let event: IntakeEvent?
    /// The newest row of its dose. Only this row offers the corrections, because a correction revises the last event.
    let isCurrent: Bool
    /// The time of the action, or the planned time of a dose with no record. It gives the order in the day.
    let time: Date
}

/// The state of the history page (spec 3 P05). The doses are keyed by slot and date, because a dose that is
/// not stored gets a new occurrence value on each read. The unconfirmed events are in `TodayState`, so closing
/// the page or a new session does not clear them (D014).
struct HistoryState {
    /// How many days one read covers, and how many days the scroll to the end adds.
    static let daysPerPage = 30

    var isOpen = false
    /// `nil` until the first read of the page ends.
    var days: [HistoryDay]?
    var looks: [ItemID: TodaySnapshot.ItemLook] = [:]
    /// The amount of each schedule version, for the rows (D091).
    var amounts: [ScheduleVersionID: Dose] = [:]
    var hasEarlier = false
    var dayCount = daysPerPage
    /// The day count of the read that the page shows. The scroll to the end adds a page only after this read.
    var loadedDayCount = 0
    /// The date of today at the read, in the device zone. The page starts at it.
    var today: LocalDate?
    var loadFailure: StorageError?
    var failure: TodayFailure?
    /// A failed correction of an as-needed dose. It has its own pair to send again (D014).
    var asNeededFailure: AsNeededFailure?
    /// Only the result of the last read shows. A new page keeps the count, so a read of an earlier page never shows.
    var readCount = 0
    /// Counts the commits. A read that started before a commit can show the state before it, so its result
    /// does not show, and the page reads again.
    var commitGeneration = 0
    /// The graph at the top of the page (D041). `nil` until its first read ends, and when there is no plan and
    /// no record. A failed read shows no graph. The timeline shows the error.
    var graph: HistoryGraph?
    var graphCounts: [LocalDate: HistoryDayCount] = [:]
    /// The first read of the graph ended. The page shows its first content after it, so the graph does not
    /// push the timeline down.
    var graphDidLoad = false
    /// Only the result of the last read of the graph shows.
    var graphReadCount = 0
}

extension AppModel {
    // MARK: Page

    /// A tap on the History button of Today.
    func openHistory() {
        resetHistory()
        history.isOpen = true
        loadHistory()
        loadHistoryGraph()
    }

    /// The full log of one item opens from the item detail while the History page is closed. It needs the days of the
    /// history, so it reads the first page for its own use (D091).
    func openItemLog() {
        guard !history.isOpen, history.days == nil else { return }
        loadHistory()
    }

    /// The full log closes. The days go, unless the History page needs them.
    func closeItemLog() {
        if !history.isOpen { resetHistory() }
    }

    /// Closes the page and forgets its days. The unconfirmed events stay in `today`.
    func resetHistory() {
        let readCount = history.readCount
        let graphReadCount = history.graphReadCount
        history = HistoryState()
        history.readCount = readCount
        history.graphReadCount = graphReadCount
    }

    /// The end of the list came on the display. One page of older days loads at a time.
    func showEarlierHistory() {
        guard history.dayCount == history.loadedDayCount else { return }
        history.dayCount += HistoryState.daysPerPage
        loadHistory()
    }

    /// The graph selected a day. The timeline loads pages of older days until it has that day.
    func showHistory(through date: LocalDate) {
        guard let today = history.today, history.loadFailure == nil else { return }
        let days = today.days(since: date) + 1
        guard days > history.dayCount else { return }
        history.dayCount = (days + HistoryState.daysPerPage - 1) / HistoryState.daysPerPage * HistoryState.daysPerPage
        loadHistory()
    }

    /// Reads the counts of the graph off the main thread (spec 9). A commit reads them again.
    func loadHistoryGraph() {
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else {
            history.graphDidLoad = true
            return
        }
        let today = LocalDate(now, in: deviceTimeZone)
        // The calendar of the user gives the first weekday. `Calendar` counts from Sunday = 1.
        let firstWeekday = Weekday(rawValue: (Calendar.current.firstWeekday + 5) % 7 + 1) ?? .monday
        history.graphReadCount += 1
        let read = history.graphReadCount
        Task {
            let oldest = HistoryGraph.oldestStart(today: today, firstWeekday: firstWeekday)
            let counts = try? await store.open().historyCounts(from: oldest, through: today, at: now, deviceTimeZone: deviceTimeZone)
            guard history.graphReadCount == read else { return }
            if let counts {
                history.graph = counts.firstDay.map { HistoryGraph(today: today, firstDay: $0, firstWeekday: firstWeekday) }
                history.graphCounts = counts.days
            }
            history.graphDidLoad = true
        }
    }

    func loadHistory() {
        analytics.markUsed(.history)
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else {
            history.days = []
            return
        }
        let today = LocalDate(now, in: deviceTimeZone)
        let days = history.dayCount
        history.readCount += 1
        let read = history.readCount
        let generation = history.commitGeneration
        Task {
            do throws(StorageError) {
                // The timeline starts at today, so the read ends at the day after it.
                let page = try await store.open().history(before: today.adding(days: 1), days: days, deviceTimeZone: deviceTimeZone)
                guard history.readCount == read else { return }
                guard history.commitGeneration == generation else { return loadHistory() }
                showHistory(page, today: today, dayCount: days)
            } catch {
                guard history.readCount == read else { return }
                history.loadFailure = error
            }
        }
    }

    private func showHistory(_ page: HistoryPage, today: LocalDate, dayCount: Int) {
        history.loadedDayCount = dayCount
        let held = Dictionary(heldRecords.map { ($0.occurrenceID, $0) }, uniquingKeysWith: { first, _ in first })
        history.days = page.days.map { day in
            var day = day
            day.doses = day.doses.map { dose in
                var dose = dose
                // A backfill that runs or failed keeps its occurrence value, so its retry sends the same one (D014).
                if !dose.isStored, let occurrence = self.today.backfills[dose.occurrence.key] {
                    dose = HistoryDose(
                        occurrence: occurrence, isStored: false, itemID: dose.itemID,
                        record: OccurrenceRecord(occurrenceID: occurrence.id)
                    )
                }
                // A read can end while a correction runs and show its event before the commit ends.
                // The row keeps the confirmed record until then (spec 7.2).
                if let record = held[dose.occurrence.id] { dose.record = record }
                return dose
            }
            day.asNeeded = shownAsNeeded(day)
            return day
        }
        history.looks = Dictionary(uniqueKeysWithValues: page.items.map {
            ($0.id, TodaySnapshot.ItemLook(
                itemID: $0.id, personID: $0.personID, name: $0.name, form: $0.form, color: $0.color,
                imageReference: $0.imageReference
            ))
        })
        history.amounts = page.amounts
        history.hasEarlier = page.hasEarlier
        history.today = today
        history.loadFailure = nil
    }

    /// The as-needed doses of a day as the store last confirmed them. A dose with a correction that runs or
    /// failed keeps its confirmed record, also when the read left it out after an undo (spec 7.2, T19).
    private func shownAsNeeded(_ day: HistoryDay) -> [HistoryAsNeededDose] {
        let state = today.asNeeded
        var doses = day.asNeeded.compactMap { dose -> HistoryAsNeededDose? in
            guard let held = state.heldDose(dose.occurrence.id) else { return dose }
            return held.map { HistoryAsNeededDose(occurrence: $0.occurrence, record: $0.record) }
        }
        let read = Set(day.asNeeded.map(\.occurrence.id))
        let missing = state.unconfirmed.values.compactMap(\.confirmed)
            + state.inFlight.compactMap { id, dose in state.unconfirmed[id] == nil ? dose : nil }
        for dose in missing where dose.occurrence.plannedDate == day.date && !read.contains(dose.id) {
            doses.append(HistoryAsNeededDose(occurrence: dose.occurrence, record: dose.record))
        }
        return doses.sorted { $0.occurrence.plannedTime < $1.occurrence.plannedTime }
    }

    // MARK: Week

    /// The items of the last 7 days with their strips, in the order of Today: the first planned time, then
    /// the name, and the as-needed items last (D054). The days of the first page hold the week.
    func historyWeeks() -> [HistoryItemWeek] {
        guard let days = history.days, let today = history.today else { return [] }
        func name(_ week: HistoryItemWeek) -> String { history.looks[week.itemID]?.name ?? "" }
        func minutes(_ week: HistoryItemWeek) -> Int { week.firstTime.map { $0.hour * 60 + $0.minute } ?? 0 }
        return History.week(days: days, today: today, now: Date()).sorted { a, b in
            if a.isAsNeeded != b.isAsNeeded { return !a.isAsNeeded }
            if minutes(a) != minutes(b) { return minutes(a) < minutes(b) }
            return name(a).localizedCaseInsensitiveCompare(name(b)) == .orderedAscending
        }
    }

    /// The days of a log, newest first. A log of an item keeps only the doses of that item (D054).
    func historyLogDays(of itemID: ItemID?) -> [HistoryDay] {
        guard let itemID else { return history.days ?? [] }
        return (history.days ?? []).map { day in
            HistoryDay(
                date: day.date,
                doses: day.doses.filter { $0.itemID == itemID },
                asNeeded: day.asNeeded.filter { $0.occurrence.itemID == itemID }
            )
        }
    }

    /// "Today", "Yesterday", then the weekday and the date, for example "Fri, Oct 9" (spec 13.2, D058).
    func historyTitle(of date: LocalDate) -> String {
        if let today = history.today {
            if date == today { return String(localized: "Today") }
            if date == today.adding(days: -1) { return String(localized: "Yesterday") }
        }
        return date.shortLabel
    }

    // MARK: Timeline

    /// The rows of one day, newest first. Every event shows, also an undo and an event that a later one
    /// replaced (D032). A planned dose of a past day with no event shows as "No record", so the day still
    /// answers "did I take it" (spec 3 P05). An open dose of today shows on Today, not here.
    func entries(of day: HistoryDay) -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        func add(_ dose: HistoryEntry.Dose, _ record: OccurrenceRecord, pending: IntakeEvent?, planned: Date?) {
            // A read can show an event that the store did not confirm. Its row says "not saved" (D014, T19).
            let events = record.events.filter { $0.id != pending?.id }
            for (index, event) in events.enumerated() {
                let kind: HistoryEntry.Kind = switch event.action {
                case .skipped: .skipped
                case .undo: .undone
                case .taken: index > 0 && events[index - 1].action == .taken ? .timeChanged : .taken
                }
                entries.append(HistoryEntry(
                    id: event.id, kind: kind, dose: dose, event: event,
                    isCurrent: pending == nil && index == events.count - 1, time: event.recordedAt
                ))
            }
            if let pending {
                entries.append(HistoryEntry(
                    id: pending.id, kind: .notSaved, dose: dose, event: pending, isCurrent: true, time: pending.recordedAt
                ))
            } else if events.isEmpty, let planned, day.date != history.today {
                // A dose that is not stored gets a new occurrence ID on each read. Its key stays.
                var id = AnyHashable(record.occurrenceID)
                if case let .planned(planned) = dose { id = AnyHashable(planned.occurrence.key) }
                entries.append(HistoryEntry(
                    id: id, kind: .noRecord, dose: dose, event: nil, isCurrent: true, time: planned
                ))
            }
        }
        for dose in day.doses {
            add(
                .planned(dose), dose.record, pending: pendingEvent(of: dose)?.event,
                planned: dose.occurrence.resolvedTime.earliestInstant
            )
        }
        for dose in day.asNeeded {
            add(.asNeeded(dose), dose.record, pending: pendingEvent(of: dose)?.event, planned: nil)
        }
        // A stable sort keeps the order of the events of one dose at the same instant.
        return entries.enumerated().sorted { ($0.element.time, $0.offset) > ($1.element.time, $1.offset) }.map(\.element)
    }

    // MARK: Corrections

    /// The event of a dose that the store did not confirm. The row shows "not saved" until a retry of this same
    /// event succeeds, also when a read shows the event (D014, T19).
    func pendingEvent(of dose: HistoryDose) -> PendingEvent? {
        today.pending[dose.occurrence.id]
    }

    func undo(_ dose: HistoryDose) {
        commit([historyEvent(for: dose, .undo)])
    }

    func markSkipped(_ dose: HistoryDose) {
        commit([historyEvent(for: dose, .skipped)])
    }

    /// Taken at the time that the user chose: a backfill of a dose with no record, a skipped dose that the user
    /// took, or a new time for a taken dose. The history keeps the earlier events (T20).
    func markTaken(_ dose: HistoryDose, at time: Date) {
        commit([historyEvent(for: dose, .taken, at: time)])
    }

    func retry(_ dose: HistoryDose) {
        guard let pending = pendingEvent(of: dose) else { return }
        commit([pending])
    }

    func retryHistory(_ failure: TodayFailure) {
        history.failure = nil
        commit(failure.events)
    }

    // MARK: Corrections of an as-needed dose

    /// The correction of an as-needed dose that the store did not confirm. Its row shows "not saved".
    func pendingEvent(of dose: HistoryAsNeededDose) -> AsNeededEvent? {
        today.asNeeded.correction(of: dose.occurrence.id)
    }

    /// The same record transaction as the card of Today, with the same D014 rules (D021).
    func undo(_ dose: HistoryAsNeededDose) {
        guard let look = history.looks[dose.occurrence.itemID] else { return }
        commitAsNeeded(event(for: AsNeededCard.Dose(dose), .undo), look: look)
    }

    func changeTime(_ dose: HistoryAsNeededDose, to time: Date) {
        guard let look = history.looks[dose.occurrence.itemID] else { return }
        commitAsNeeded(event(for: AsNeededCard.Dose(dose), .taken, at: time), look: look)
    }

    func retry(_ dose: HistoryAsNeededDose) {
        guard let entry = today.asNeeded.unconfirmed[dose.occurrence.id], entry.confirmed != nil else { return }
        commitAsNeeded(entry.pending, look: entry.look)
    }

    // MARK: Record transaction

    /// The record transaction of Today runs it, or the backfill for a dose that is not stored (spec 7.2).
    private func historyEvent(for dose: HistoryDose, _ action: IntakeAction, at time: Date? = nil) -> PendingEvent {
        let now = Date()
        return PendingEvent(
            event: IntakeEvent(
                occurrenceID: dose.occurrence.id,
                action: action,
                occurredAt: time ?? now,
                recordedAt: now,
                source: .app,
                supersedes: dose.record.events.last?.id
            ),
            scheduleVersionID: dose.occurrence.scheduleVersionID,
            backfill: dose.isStored ? nil : dose.occurrence
        )
    }

    /// Puts a committed as-needed record in place. An undone dose stays with its events (D032).
    func historyDidCommitAsNeeded(_ record: OccurrenceRecord, of occurrence: AsNeededOccurrence) {
        history.commitGeneration += 1
        history.days = history.days?.map { day in
            var day = day
            if let index = day.asNeeded.firstIndex(where: { $0.occurrence.id == occurrence.id }) {
                day.asNeeded[index].record = record
            }
            return day
        }
    }

    /// Every commit calls this, also one of Today or of the reminder choice, because a dose can show on both pages.
    func historyDidCommit(_ records: [OccurrenceRecord]) {
        history.commitGeneration += 1
        if history.isOpen { loadHistoryGraph() }
        let byID = Dictionary(records.map { ($0.occurrenceID, $0) }, uniquingKeysWith: { _, last in last })
        history.days = history.days?.map { day in
            var day = day
            day.doses = day.doses.map { dose in
                guard let record = byID[dose.occurrence.id] else { return dose }
                return HistoryDose(occurrence: dose.occurrence, isStored: true, itemID: dose.itemID, record: record)
            }
            return day
        }
    }
}
