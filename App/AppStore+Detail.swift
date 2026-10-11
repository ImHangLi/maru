import Foundation
import MaruCore
import MaruDatabase

/// What the detail page of one item shows (spec 3 P04).
struct ItemDetail: Equatable, Sendable {
    /// One recorded occurrence or as-needed dose: its date and time, and the event that is valid now.
    struct Recent: Identifiable, Equatable, Sendable {
        let id: OccurrenceID
        let plannedDate: LocalDate
        let plannedTime: WallClockTime
        /// `true` for an as-needed dose (D021). It has no slot, so it shows no part of the day.
        let isAsNeeded: Bool
        let event: IntakeEvent
    }

    /// The day of the next dose of a plan that repeats every second day (D036).
    struct NextDose: Equatable, Sendable {
        let date: LocalDate
        /// 0 for today and 1 for tomorrow.
        let daysFromToday: Int
    }

    /// The number of days that the recent records cover, today included.
    static let recentDays = 7

    let item: Item
    /// `nil` for an item with no time (T02).
    let schedule: Schedule?
    /// `nil` for a plan that does not repeat every second day.
    let nextDose: NextDose?
    /// Taken and skipped occurrences of the last `recentDays` days, newest first. An undone record does not show.
    let recent: [Recent]
}

extension AppStore {
    /// The item, its schedule, and its recent records. `nil` when the store has no such item.
    ///
    /// The records come from the intake events, not from the plan, so a time that the user changed
    /// still shows its record (D019).
    func detail(of itemID: ItemID, at now: Date, deviceTimeZone: NamedTimeZone?) async throws(StorageError) -> ItemDetail? {
        let store = try open()
        guard let item = try await store.item(id: itemID) else { return nil }
        let schedule = try await store.schedules(of: itemID).first
        let since = LocalDate(now, in: deviceTimeZone ?? .utc).adding(days: 1 - ItemDetail.recentDays)
        let occurrences = try await store.recordedOccurrences(of: itemID, since: since)
        let doses = try await store.recordedAsNeededOccurrences(of: itemID, since: since)
        let records = try await store.records(of: occurrences.map(\.id) + doses.map(\.id))
        let scheduled = occurrences.map { ($0.id, $0.plannedDate, $0.plannedTime, false) }
        let asNeeded = doses.map { ($0.id, $0.plannedDate, $0.plannedTime, true) }
        // An item can have both kinds in the range, for example after the user removed its times.
        let recent = (scheduled + asNeeded)
            .compactMap { id, date, time, isAsNeeded in
                records[id]?.currentEvent.map {
                    ItemDetail.Recent(id: id, plannedDate: date, plannedTime: time, isAsNeeded: isAsNeeded, event: $0)
                }
            }
            .sorted { ($0.plannedDate, $0.plannedTime, $0.event.occurredAt) > ($1.plannedDate, $1.plannedTime, $1.event.occurredAt) }
        let nextDose = schedule.flatMap { schedule in
            deviceTimeZone.flatMap { Self.nextDose(of: schedule, at: now, deviceTimeZone: $0) }
        }
        return ItemDetail(item: item, schedule: schedule, nextDose: nextDose, recent: recent)
    }

    /// The first date from today on which a plan of every second day has a time that is still to come.
    /// It reads the plan and not the records: a dose of today that the user recorded early still counts
    /// until its time. So today after the last time gives the day after tomorrow.
    private static func nextDose(of schedule: Schedule, at now: Date, deviceTimeZone: NamedTimeZone) -> ItemDetail.NextDose? {
        guard let version = schedule.versions.last, version.everyOtherDayFrom != nil else { return nil }
        let zone = if case let .fixed(zone) = version.timeZonePolicy { zone } else { deviceTimeZone }
        let today = LocalDate(now, in: zone)
        for days in 0...6 {
            let date = today.adding(days: days)
            let isToCome = schedule.plannedOccurrences(on: date, deviceTimeZone: deviceTimeZone).contains {
                $0.timeZone.resolve($0.plannedTime, on: date).earliestInstant > now
            }
            if isToCome { return ItemDetail.NextDose(date: date, daysFromToday: days) }
        }
        return nil
    }

    /// Turns the reminders of the item on or off. The item stays on Today and My Items, and the user can still
    /// record it (T07). It returns the schedule, or `nil` when the item has no schedule.
    /// `generation` is the generation of the data that the model read (D040).
    func setReminders(on isOn: Bool, for itemID: ItemID, generation: Int) async throws(StorageError) -> Schedule? {
        let store = try open()
        guard var schedule = try await store.schedules(of: itemID).first else { return nil }
        guard schedule.isEnabled != isOn else { return schedule }
        schedule.isEnabled = isOn
        try await store.save(schedule, generation: generation)
        return schedule
    }

    /// Archives or restores the item. The records stay (T08). It returns the item and its schedule, if any.
    /// `generation` is the generation of the data that the model read (D040).
    func setArchived(
        _ isArchived: Bool,
        for itemID: ItemID,
        generation: Int
    ) async throws(StorageError) -> (item: Item, schedule: Schedule?)? {
        let store = try open()
        guard var item = try await store.item(id: itemID) else { return nil }
        if item.isArchived != isArchived {
            item.isArchived = isArchived
            try await store.save(item, generation: generation)
        }
        return (item, try await store.schedules(of: itemID).first)
    }

    /// Deletes the item with its schedules and its records, in one transaction (D033). It returns the IDs of
    /// the deleted schedules and of their versions, or `nil` when the store has no such item.
    func deleteItem(
        _ itemID: ItemID,
        generation: Int
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        try await open().deleteItem(itemID, generation: generation)
    }
}
