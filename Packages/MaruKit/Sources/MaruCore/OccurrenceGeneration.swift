import Foundation

/// The plan dates that one generation run covers: today, and one day on each side (spec 7.3, 8.1).
///
/// Yesterday is there for a late record after midnight, and tomorrow for an intake that the user takes early.
/// A schedule with no end date never gets rows for more dates than these.
public struct OccurrenceWindow: Hashable, Sendable {
    public static let daysBefore = 1
    public static let daysAfter = 1

    public let today: LocalDate

    public init(today: LocalDate) {
        self.today = today
    }

    /// The window at an instant. Today is the calendar date in `timeZone` at that instant.
    public init(at now: Date, in timeZone: NamedTimeZone) {
        self.init(today: LocalDate(now, in: timeZone))
    }

    public var dates: [LocalDate] {
        (-Self.daysBefore...Self.daysAfter).map { today.adding(days: $0) }
    }

    public func contains(_ date: LocalDate) -> Bool {
        dates.contains(date)
    }
}

/// One slot on one date as the schedule plans it now. It has no ID. The stored occurrence with the same key gives it one.
public struct PlannedOccurrence: Hashable, Sendable {
    public let slotID: ScheduleSlotID
    public let plannedDate: LocalDate
    public let plannedTime: WallClockTime
    public let timeZone: NamedTimeZone
    public let scheduleVersionID: ScheduleVersionID

    public var key: OccurrenceKey {
        OccurrenceKey(slotID: slotID, plannedDate: plannedDate)
    }

    func occurrence(id: OccurrenceID) -> Occurrence {
        Occurrence(
            id: id,
            slotID: slotID,
            plannedDate: plannedDate,
            plannedTime: plannedTime,
            timeZone: timeZone,
            scheduleVersionID: scheduleVersionID
        )
    }
}

/// An occurrence from the store, and whether it has a current taken or skipped record. An undone record does not count (D095).
public struct StoredOccurrence: Hashable, Sendable {
    public let occurrence: Occurrence
    public let isRecorded: Bool

    public init(occurrence: Occurrence, isRecorded: Bool) {
        self.occurrence = occurrence
        self.isRecorded = isRecorded
    }
}

extension Occurrence {
    /// The instant of the planned time in the time zone of the occurrence, with the clock-change cases (T25).
    public var resolvedTime: ResolvedLocalTime {
        timeZone.resolve(plannedTime, on: plannedDate)
    }
}

extension Schedule {
    /// The occurrences that the schedule plans for one date: one for each slot of the version in force.
    /// It plans nothing before the first version, after the end date, or on a date that the repeat rule does not have.
    ///
    /// The time zone is the named zone of a fixed policy, or `deviceTimeZone` when the version follows the device.
    /// `isEnabled` turns the reminders off. The user can still record, so it does not change the plan (T07).
    public func plannedOccurrences(on date: LocalDate, deviceTimeZone: NamedTimeZone) -> [PlannedOccurrence] {
        if let endDate, date > endDate { return [] }
        guard let version = version(on: date), version.isDue(on: date) else { return [] }
        let timeZone = switch version.timeZonePolicy {
        case let .fixed(zone): zone
        case .followsDevice: deviceTimeZone
        }
        return version.slotTimes.map { slotTime in
            PlannedOccurrence(
                slotID: slotTime.slotID,
                plannedDate: date,
                plannedTime: slotTime.time,
                timeZone: timeZone,
                scheduleVersionID: version.id
            )
        }
    }
}

/// One generation run: which occurrences exist around `now`, and what the run does with the stored ones.
///
/// The clock and the device time zone are inputs. The rules read no system state.
public struct OccurrenceGeneration: Sendable {
    public let now: Date
    public let deviceTimeZone: NamedTimeZone

    public init(now: Date, deviceTimeZone: NamedTimeZone) {
        self.now = now
        self.deviceTimeZone = deviceTimeZone
    }

    /// What a run gives. The store inserts `created` and updates `replanned`. It changes nothing else.
    public struct Outcome: Hashable, Sendable {
        /// The occurrences of the window, in the order of the planned instant.
        public internal(set) var occurrences: [Occurrence] = []
        /// Occurrences that the store does not have.
        public internal(set) var created: [Occurrence] = []
        /// Stored occurrences that now have another plan. Each keeps its ID and its key.
        public internal(set) var replanned: [Occurrence] = []
    }

    /// Every plan date that a window can have now. The calendar date of a time zone is the UTC date or one day
    /// from it, so the window of each zone is inside these five dates, also for two zones across the date line.
    public var candidateDates: [LocalDate] {
        let today = LocalDate(now, in: .utc)
        return (-(OccurrenceWindow.daysBefore + 1)...(OccurrenceWindow.daysAfter + 1)).map { today.adding(days: $0) }
    }

    /// The occurrences that a schedule plans in the window. Each plan uses the window of its own time zone,
    /// so a fixed zone keeps its own calendar when the device is in another zone (spec 8.5).
    public func plannedOccurrences(of schedule: Schedule) -> [PlannedOccurrence] {
        candidateDates
            .flatMap { schedule.plannedOccurrences(on: $0, deviceTimeZone: deviceTimeZone) }
            .filter { OccurrenceWindow(at: now, in: $0.timeZone).contains($0.plannedDate) }
    }

    /// Matches the plan with the stored occurrences by key (slot and plan date), so a slot never gets
    /// a second occurrence on one date (T17).
    ///
    /// - A plan with no stored occurrence gives a new occurrence.
    /// - A stored occurrence follows the plan while it has no record and its date is not in the past.
    ///   It keeps its ID. So an edit in the middle of a day moves a dose that is not recorded, also after an undo (D095).
    /// - A stored occurrence with a record, or with a date before today, never changes (spec 7.2).
    ///   A date is before today when it is in the past in the stored time zone or in the time zone of the plan,
    ///   so a change of the zone does not move an occurrence of a day that is over.
    /// - A stored occurrence with a record stays in the result when the plan no longer has it.
    ///   One with no record is left out, and it stays in the store.
    /// - The schedules of an archived item plan nothing (spec 8.5).
    ///
    /// - Parameter stored: The stored occurrences on `candidateDates`.
    public func outcome(items: [Item], schedules: [Schedule], stored: [StoredOccurrence]) -> Outcome {
        let activeItems = Set(items.filter { !$0.isArchived }.map(\.id))
        var unplanned = Dictionary(stored.map { ($0.occurrence.key, $0) }, uniquingKeysWith: { first, _ in first })
        var planned = Set<OccurrenceKey>()
        var outcome = Outcome()
        for plan in schedules.filter({ activeItems.contains($0.itemID) }).flatMap(plannedOccurrences(of:))
        where planned.insert(plan.key).inserted {
            guard let existing = unplanned.removeValue(forKey: plan.key) else {
                let occurrence = plan.occurrence(id: OccurrenceID())
                outcome.created.append(occurrence)
                outcome.occurrences.append(occurrence)
                continue
            }
            let isPast = [existing.occurrence.timeZone, plan.timeZone].contains { plan.plannedDate < LocalDate(now, in: $0) }
            let occurrence = existing.isRecorded || isPast ? existing.occurrence : plan.occurrence(id: existing.occurrence.id)
            if occurrence != existing.occurrence {
                outcome.replanned.append(occurrence)
            }
            outcome.occurrences.append(occurrence)
        }
        outcome.occurrences += stored.map(\.occurrence).filter { occurrence in
            unplanned[occurrence.key]?.isRecorded == true
                && OccurrenceWindow(at: now, in: occurrence.timeZone).contains(occurrence.plannedDate)
        }
        // Occurrences with the same instant keep the order of the plan.
        let instants = outcome.occurrences.map(\.resolvedTime.earliestInstant)
        outcome.occurrences = outcome.occurrences.indices
            .sorted { (instants[$0], $0) < (instants[$1], $1) }
            .map { outcome.occurrences[$0] }
        return outcome
    }
}
