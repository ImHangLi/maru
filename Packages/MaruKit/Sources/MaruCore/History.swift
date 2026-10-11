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
///   the first version of an item. An archived item shows only its records, because the store does not
///   keep the date of the archive.
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
        let active = activeSchedules(schedules, items: items)
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
    public static func counts(
        _ dates: [LocalDate],
        items: [Item],
        schedules: [Schedule],
        stored: [StoredDoseState],
        deviceTimeZone: NamedTimeZone
    ) -> [LocalDate: HistoryDayCount] {
        let active = activeSchedules(schedules, items: items)
        let recordedByDate = Dictionary(grouping: stored.filter(\.hasEvents), by: \.key.plannedDate)
        var counts: [LocalDate: HistoryDayCount] = [:]
        for date in dates {
            let recorded = recordedByDate[date] ?? []
            let planned = plannedDoses(on: date, besides: Set(recorded.map(\.key)), schedules: active, deviceTimeZone: deviceTimeZone)
            let scheduled = recorded.count + planned.count
            guard scheduled > 0 else { continue }
            counts[date] = HistoryDayCount(scheduled: scheduled, taken: recorded.filter(\.isTaken).count)
        }
        return counts
    }

    /// An archived item gets no planned dose. Its records still show.
    private static func activeSchedules(_ schedules: [Schedule], items: [Item]) -> [Schedule] {
        let activeItems = Set(items.filter { !$0.isArchived }.map(\.id))
        return schedules.filter { activeItems.contains($0.itemID) }
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
