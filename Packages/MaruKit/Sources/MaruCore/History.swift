import Foundation

/// One dose on a past day of the history: a dose with a record, or a dose that the plan of that day had (spec 3 P05).
public struct HistoryDose: Hashable, Sendable {
    /// The stored occurrence, or a new value for a planned dose that no generation run stored.
    /// A new value goes to the store with its first event. See `LocalStore.recordBackfill`.
    public let occurrence: Occurrence
    public let isStored: Bool
    public let itemID: ItemID
    /// The stored history. Empty for a dose that is not stored.
    public var record: OccurrenceRecord

    public init(occurrence: Occurrence, isStored: Bool, itemID: ItemID, record: OccurrenceRecord) {
        self.occurrence = occurrence
        self.isStored = isStored
        self.itemID = itemID
        self.record = record
    }
}

/// One as-needed dose of a day (D021). It has no plan, so only a dose with an event shows.
public struct HistoryAsNeededDose: Hashable, Sendable {
    public let occurrence: AsNeededOccurrence
    public var record: OccurrenceRecord

    public init(occurrence: AsNeededOccurrence, record: OccurrenceRecord) {
        self.occurrence = occurrence
        self.record = record
    }
}

public struct HistoryDay: Hashable, Sendable {
    public let date: LocalDate
    /// In the order of the planned time.
    public var doses: [HistoryDose]
    /// The as-needed doses of the date, in the order of the record time.
    public var asNeeded: [HistoryAsNeededDose]

    public init(date: LocalDate, doses: [HistoryDose], asNeeded: [HistoryAsNeededDose] = []) {
        self.date = date
        self.doses = doses
        self.asNeeded = asNeeded
    }
}

/// A stored occurrence of the history range, with its item and its record.
public struct StoredHistoryDose: Hashable, Sendable {
    public let occurrence: Occurrence
    public let itemID: ItemID
    public let record: OccurrenceRecord

    public init(occurrence: Occurrence, itemID: ItemID, record: OccurrenceRecord) {
        self.occurrence = occurrence
        self.itemID = itemID
        self.record = record
    }
}

/// A stored planned dose of the graph range: its key and what its record says (D041).
public struct StoredDoseState: Hashable, Sendable {
    public let key: OccurrenceKey
    /// The dose has an event, also when the last event is an undo.
    public let hasEvents: Bool
    public let isTaken: Bool

    public init(key: OccurrenceKey, hasEvents: Bool, isTaken: Bool) {
        self.key = key
        self.hasEvents = hasEvents
        self.isTaken = isTaken
    }
}

/// The planned doses of one day and how many of them are taken (D041).
public struct HistoryDayCount: Hashable, Sendable {
    public let scheduled: Int
    public let taken: Int

    public init(scheduled: Int, taken: Int) {
        self.scheduled = scheduled
        self.taken = taken
    }
}

/// The rules of the history screen (spec 3 P05, spec 4, D019).
///
/// The history reads by records, not by occurrence rows:
/// - A dose with an intake event always shows, also when the plan no longer has it, and also after an undo.
///   The timeline shows every action (D032).
/// - A dose with no event shows only when the plan of that day has it. A stored occurrence that is
///   no longer planned and has no event does not show.
/// - The plan of a day is the schedule version in force on that day, so the history has no day before
///   the first version of an item. An archived item keeps its plan up to the day before its archive, so its past
///   doses with no record stay (D091). An item archived before the app kept the archive time shows only its records.
/// - An as-needed dose has no plan, so it shows only with an event (D021).
public enum History {
    public static func days(
        _ dates: [LocalDate],
        items: [Item],
        schedules: [Schedule],
        stored: [StoredHistoryDose],
        asNeeded: [HistoryAsNeededDose] = [],
        deviceTimeZone: NamedTimeZone
    ) -> [HistoryDay] {
        let storedByKey = Dictionary(stored.map { ($0.occurrence.key, $0) }, uniquingKeysWith: { first, _ in first })
        let active = pastSchedules(schedules, items: items, deviceTimeZone: deviceTimeZone)
        return dates.compactMap { date in
            var doses: [HistoryDose] = []
            for dose in stored where dose.occurrence.plannedDate == date && !dose.record.events.isEmpty {
                doses.append(HistoryDose(occurrence: dose.occurrence, isStored: true, itemID: dose.itemID, record: dose.record))
            }
            let recorded = Set(doses.map(\.occurrence.key))
            for (itemID, plan) in plannedDoses(on: date, besides: recorded, schedules: active, deviceTimeZone: deviceTimeZone) {
                if let dose = storedByKey[plan.key] {
                    doses.append(HistoryDose(occurrence: dose.occurrence, isStored: true, itemID: dose.itemID, record: dose.record))
                } else {
                    let occurrence = plan.occurrence(id: OccurrenceID())
                    doses.append(
                        HistoryDose(occurrence: occurrence, isStored: false, itemID: itemID, record: OccurrenceRecord(occurrenceID: occurrence.id))
                    )
                }
            }
            let asNeeded = asNeeded.filter { $0.occurrence.plannedDate == date && !$0.record.events.isEmpty }
            guard !doses.isEmpty || !asNeeded.isEmpty else { return nil }
            // A stable sort keeps the order of the plan for the same time.
            let ordered = doses.enumerated().sorted { ($0.element.occurrence.plannedTime, $0.offset) < ($1.element.occurrence.plannedTime, $1.offset) }
            return HistoryDay(date: date, doses: ordered.map(\.element), asNeeded: asNeeded)
        }
    }

    /// The planned doses of each date and how many of them are taken, for the graph of the history page (D041).
    /// A day has the same doses as in `days`, so the graph and the timeline agree. A skipped dose is not taken.
    /// An as-needed dose has no plan, so it does not count. A date with no dose has no entry.
    /// A planned dose of `today` with no event and a time after `now` is not due yet, so it does not count (`isCounted`).
    public static func counts(
        _ dates: [LocalDate],
        items: [Item],
        schedules: [Schedule],
        stored: [StoredDoseState],
        today: LocalDate,
        now: Date,
        deviceTimeZone: NamedTimeZone
    ) -> [LocalDate: HistoryDayCount] {
        let active = pastSchedules(schedules, items: items, deviceTimeZone: deviceTimeZone)
        let recordedByDate = Dictionary(grouping: stored.filter(\.hasEvents), by: \.key.plannedDate)
        var counts: [LocalDate: HistoryDayCount] = [:]
        for date in dates {
            let recorded = recordedByDate[date] ?? []
            let planned = plannedDoses(on: date, besides: Set(recorded.map(\.key)), schedules: active, deviceTimeZone: deviceTimeZone)
                .filter { isCounted(hasEvent: false, date: date, plannedAt: $0.plan.timeZone.resolve($0.plan.plannedTime, on: date).earliestInstant, today: today, now: now) }
            let scheduled = recorded.count + planned.count
            guard scheduled > 0 else { continue }
            counts[date] = HistoryDayCount(scheduled: scheduled, taken: recorded.filter(\.isTaken).count)
        }
        return counts
    }

    /// The one rule of what counts in a summary, the week strip, and the graph (D091, R5). A dose with an event always
    /// counts. A dose with no event counts when its day is over, or when its time came. A dose of today that is not due yet
    /// is nothing planned until its time, so no view shows a miss before the user can take the dose.
    public static func isCounted(hasEvent: Bool, date: LocalDate, plannedAt: Date, today: LocalDate, now: Date) -> Bool {
        hasEvent || date != today || plannedAt <= now
    }

    /// The schedules that plan doses in the past. An item that is not archived keeps its schedules. An archived item keeps
    /// them up to the day before its archive, so its doses with no record stay in the history and the graph (D091).
    /// An archived item with no archive time plans nothing. Its records still show.
    private static func pastSchedules(_ schedules: [Schedule], items: [Item], deviceTimeZone: NamedTimeZone) -> [Schedule] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return schedules.compactMap { schedule in
            guard let item = byID[schedule.itemID] else { return nil }
            guard item.isArchived else { return schedule }
            guard let archivedAt = item.archivedAt else { return nil }
            var bounded = schedule
            let last = LocalDate(archivedAt, in: deviceTimeZone).adding(days: -1)
            bounded.endDate = min(last, schedule.endDate ?? last)
            return bounded
        }
    }

    /// The doses of the plan of a date that are not in `recorded`, the stored doses of the date with an event.
    private static func plannedDoses(
        on date: LocalDate,
        besides recorded: Set<OccurrenceKey>,
        schedules: [Schedule],
        deviceTimeZone: NamedTimeZone
    ) -> [(itemID: ItemID, plan: PlannedOccurrence)] {
        var keys = recorded
        var doses: [(itemID: ItemID, plan: PlannedOccurrence)] = []
        for schedule in schedules {
            for plan in schedule.plannedOccurrences(on: date, deviceTimeZone: deviceTimeZone) where keys.insert(plan.key).inserted {
                doses.append((schedule.itemID, plan))
            }
        }
        return doses
    }

    /// The first date that can have a dose: the first schedule version of any item, or the first stored record.
    public static func earliestDate(schedules: [Schedule], stored: [LocalDate]) -> LocalDate? {
        (schedules.compactMap { $0.versions.first?.effectiveFrom } + stored).min()
    }
}

/// What one day of the week strip says about one item (D054).
public enum HistoryDayMark: Hashable, Sendable {
    /// Nothing planned and no as-needed dose taken.
    case none
    /// Planned, and no dose taken.
    case missed
    /// Planned, and some doses taken.
    case some
    /// Every planned dose taken, or an as-needed dose taken.
    case all
}

/// The last 7 days of one item, oldest first (D054).
public struct HistoryItemWeek: Hashable, Sendable {
    public let itemID: ItemID
    /// 7 marks. The last one is today.
    public let marks: [HistoryDayMark]
    /// The item had no planned dose in the week.
    public let isAsNeeded: Bool
    /// The parts of the day of the planned doses of the week.
    public let dayParts: [DayPart]
    /// The earliest planned time of the week. It orders the list. `nil` for an as-needed item.
    public let firstTime: WallClockTime?
    /// The doses of the week that are taken, planned or as needed.
    public let takenDoses: Int
    /// The planned doses of the week that are skipped.
    public let skippedDoses: Int
    /// The planned doses of the week that are due and have no record.
    public let unrecordedDoses: Int

    /// The days with every planned dose taken, or with an as-needed dose taken.
    public var takenDays: Int { marks.filter { $0 == .all }.count }
    /// The days with a planned dose. An as-needed item counts all 7 days.
    public var countedDays: Int { isAsNeeded ? marks.count : marks.filter { $0 != .none }.count }
}

extension History {
    /// One entry for each item that had a planned dose or a taken as-needed dose in the 7 days up to `today`.
    /// `days` has the rules of `days(_:items:schedules:stored:asNeeded:deviceTimeZone:)`, so the strip and the
    /// timeline cannot disagree. An archived item has only its records there, so it shows only with one.
    ///
    /// A planned dose of today with no event and a time after `now` is not due yet. It counts as nothing
    /// planned until its time, so the strip does not show a miss before the user can take the dose.
    public static func week(days: [HistoryDay], today: LocalDate, now: Date) -> [HistoryItemWeek] {
        let dates = (0..<7).map { today.adding(days: $0 - 6) }
        var planned: [ItemID: [LocalDate: [HistoryDose]]] = [:]
        var asNeeded: [ItemID: Set<LocalDate>] = [:]
        var asNeededTaken: [ItemID: Int] = [:]
        for day in days where dates.contains(day.date) {
            for dose in day.doses {
                let isDue = isCounted(
                    hasEvent: !dose.record.events.isEmpty, date: day.date, plannedAt: dose.occurrence.resolvedTime.earliestInstant,
                    today: today, now: now
                )
                if isDue { planned[dose.itemID, default: [:]][day.date, default: []].append(dose) }
            }
            for dose in day.asNeeded where dose.record.status == .taken {
                asNeeded[dose.occurrence.itemID, default: []].insert(day.date)
                asNeededTaken[dose.occurrence.itemID, default: 0] += 1
            }
        }
        return Set(planned.keys).union(asNeeded.keys).map { itemID in
            let byDate = planned[itemID] ?? [:]
            let marks = dates.map { date -> HistoryDayMark in
                if let doses = byDate[date] {
                    let taken = doses.filter { $0.record.status == .taken }.count
                    return taken == doses.count ? .all : taken == 0 ? .missed : .some
                }
                return asNeeded[itemID]?.contains(date) == true ? .all : .none
            }
            let doses = byDate.values.flatMap { $0 }
            let times = doses.map(\.occurrence.plannedTime)
            func count(_ status: OccurrenceStatus) -> Int { doses.filter { $0.record.status == status }.count }
            return HistoryItemWeek(
                itemID: itemID, marks: marks, isAsNeeded: doses.isEmpty,
                dayParts: DayPart.allCases.filter { part in times.contains { DayPart($0) == part } },
                firstTime: times.min(),
                takenDoses: count(.taken) + (asNeededTaken[itemID] ?? 0),
                skippedDoses: count(.skipped),
                unrecordedDoses: count(.unrecorded)
            )
        }
    }
}
