import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications

/// The rows of a tapped reminder on Today.
struct TodayFocus: Equatable {
    let id = UUID()
    let keys: Set<OccurrenceKey>
}

/// The candidates of a tapped reminder that the resolver could not make certain (spec 8.3, T15, T24).
/// The user chooses one, or opens Today. The app records nothing until the user records.
struct ReminderChoice: Identifiable {
    struct Candidate: Identifiable {
        let planned: PlannedOccurrence
        let name: String
        let amount: String?
        /// `nil` when no generation run reached the date, so the store has no occurrence to record.
        let occurrence: Occurrence?
        var record: OccurrenceRecord?
        /// The time of the tap.
        let now: Date

        var id: OccurrenceKey { planned.key }

        /// The time zone of the stored occurrence, which keeps its zone after travel. The zone of the plan only
        /// when no occurrence is stored. Today uses the same rule (spec 8.5).
        var timeZone: NamedTimeZone { occurrence?.timeZone ?? planned.timeZone }
        var plannedTime: WallClockTime { occurrence?.plannedTime ?? planned.plannedTime }

        var isToday: Bool { TodaySnapshot.isToday(planned.plannedDate, in: timeZone, at: now) }
        var isYesterday: Bool { planned.plannedDate == LocalDate(now, in: timeZone).adding(days: -1) }

        /// The planned instant of the occurrence. It is not the time of an intake.
        var plannedInstant: Date {
            timeZone.resolve(plannedTime, on: planned.plannedDate).earliestInstant
        }

        var takenAt: Date? {
            record?.currentEvent.flatMap { $0.action == .taken ? $0.occurredAt : nil }
        }
    }

    let id = UUID()
    private(set) var candidates: [Candidate]
    let doubts: Set<ReminderTapDoubt>

    init(candidates: [Candidate], doubts: Set<ReminderTapDoubt>) {
        self.candidates = candidates
        self.doubts = doubts
    }

    /// Puts committed or held records in place, as Today does.
    mutating func apply(_ records: [OccurrenceRecord]) {
        for record in records {
            for c in candidates.indices where candidates[c].occurrence?.id == record.occurrenceID {
                candidates[c].record = record
            }
        }
    }
}

extension AppModel {
    /// A tap on a delivered reminder. Opens Today, then finds the occurrences of the reminder (spec 8.3).
    ///
    /// It never records. A certain reminder scrolls Today to its card and opens it. A reminder that is not
    /// certain asks the user to choose. A reminder of no series opens Today.
    func openReminder(_ reminder: DeliveredReminder) {
        analytics.markUsed(.notification)
        selectedTab = .today
        today.lockedTap = nil
        today.choice = nil
        Task { await resolve(reminder) }
    }

    func retryLockedTap() {
        guard let reminder = today.lockedTap else { return }
        refresh()
        openReminder(reminder)
    }

    /// Opens the card of a candidate of today.
    func show(_ candidate: ReminderChoice.Candidate) {
        today.choice = nil
        focus([candidate.planned.key])
    }

    /// The event of a candidate that the store did not confirm. Until a retry succeeds, the candidate is
    /// "not saved", also when the store shows the event, and only that same event can go again (D014, T19).
    func pendingEvent(of candidate: ReminderChoice.Candidate) -> PendingEvent? {
        candidate.occurrence.flatMap { today.pending[$0.id] }
    }

    /// Sends the event of a candidate that the store did not confirm again. A new event is not made (D014).
    func retry(_ candidate: ReminderChoice.Candidate) {
        guard let pending = pendingEvent(of: candidate) else { return }
        commit([pending])
        today.choice = nil
    }

    /// Records a candidate of another day as taken at the time that the user chose (T15, T24).
    /// A taken record before it stays in the history (T20).
    func recordTaken(_ candidate: ReminderChoice.Candidate, at time: Date) {
        guard let occurrence = candidate.occurrence, pendingEvent(of: candidate) == nil else { return }
        // The commit reads the record that the choice shows, so the choice closes after it.
        defer { today.choice = nil }
        commit([
            PendingEvent(
                event: IntakeEvent(
                    occurrenceID: occurrence.id,
                    action: .taken,
                    occurredAt: time,
                    recordedAt: Date(),
                    source: .app,
                    supersedes: candidate.record?.events.last?.id
                ),
                scheduleVersionID: occurrence.scheduleVersionID
            ),
        ])
    }

    func focus(_ keys: Set<OccurrenceKey>) {
        today.focus = TodayFocus(keys: keys)
    }

    private func resolve(_ reminder: DeliveredReminder) async {
        let now = Date()
        // With no region name for the device zone, Today says why it shows no items.
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        let generation = dataGeneration
        do throws(StorageError) {
            let inputs = try await store.tapInputs()
            let resolver = ReminderTapResolver(
                now: now, deviceTimeZone: deviceTimeZone, observedTimeZone: DefaultsTimeZoneRecord().load()
            )
            let planned: [PlannedOccurrence]
            let doubts: Set<ReminderTapDoubt>
            switch resolver.resolve(reminder, items: inputs.items, schedules: inputs.schedules) {
            case let .resolved(occurrences):
                (planned, doubts) = (occurrences, [])
            case let .confirm(candidates, confirmDoubts):
                (planned, doubts) = (candidates, confirmDoubts)
            case .notSeries:
                // A one-time follow-up request (issue #21) or an unknown request opens Today.
                return
            }
            // With no candidate, Today is the page to open.
            guard !planned.isEmpty else { return }
            let stored = try await store.stored(planned)
            // A restore replaced the data that the reads saw.
            guard generation == dataGeneration else { return }
            let candidates = Self.candidates(
                planned, stored: stored, items: inputs.items, schedules: inputs.schedules, at: now
            )
            if doubts.isEmpty {
                // A stored occurrence keeps its zone after travel, so a certain date can be off Today.
                // Today then has no row to open, and the user confirms in the sheet (spec 8.5).
                guard candidates.allSatisfy(\.isToday) else {
                    return show(ReminderChoice(candidates: candidates, doubts: [.otherDay]))
                }
                return focus(Set(planned.map(\.key)))
            }
            // Every dose of the reminder is of today and has a record. The sheet has nothing to ask, so Today opens on them.
            if candidates.allSatisfy({ $0.isToday && $0.record?.currentEvent != nil }) {
                return focus(Set(planned.map(\.key)))
            }
            show(ReminderChoice(candidates: candidates, doubts: doubts))
        } catch {
            if error == .unavailable {
                // The database is protected while the iPhone is locked. Nothing is read or recorded (T40).
                today.lockedTap = reminder
            } else {
                // The refresh shows the storage problem in place of Today (spec 7.3).
                refresh()
            }
        }
    }

    private func show(_ choice: ReminderChoice) {
        var choice = choice
        // A running transaction can show its event before a success. Show the confirmed record (T19).
        choice.apply(heldRecords)
        today.choice = choice
    }

    private static func candidates(
        _ planned: [PlannedOccurrence],
        stored: [OccurrenceKey: (occurrence: Occurrence, record: OccurrenceRecord)],
        items: [Item],
        schedules: [Schedule],
        at now: Date
    ) -> [ReminderChoice.Candidate] {
        let names = Dictionary(items.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        var itemBySlot: [ScheduleSlotID: ItemID] = [:]
        var doses: [ScheduleVersionID: Dose] = [:]
        for schedule in schedules {
            for slot in schedule.slots { itemBySlot[slot.id] = schedule.itemID }
            for version in schedule.versions { doses[version.id] = version.dose }
        }
        return planned.map { candidate in
            // A stored occurrence keeps the version that it was made from, and the record uses that version.
            // So the sheet shows the dose of the same version (spec 8.3).
            let versionID = stored[candidate.key]?.occurrence.scheduleVersionID ?? candidate.scheduleVersionID
            return ReminderChoice.Candidate(
                planned: candidate,
                name: itemBySlot[candidate.slotID].flatMap { names[$0] } ?? "",
                amount: doses[versionID]?.text,
                occurrence: stored[candidate.key]?.occurrence,
                record: stored[candidate.key]?.record,
                now: now
            )
        }
    }
}
