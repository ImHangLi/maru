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

    /// The number of days that the recent records cover, today included.
    static let recentDays = 7

    let item: Item
    /// `nil` for an item with no time (T02).
    let schedule: Schedule?
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
        return ItemDetail(item: item, schedule: schedule, recent: recent)
    }

    /// Turns the reminders of the item on or off. The item stays on Today and My Items, and the user can still
    /// record it (T07). It returns the schedule, or `nil` when the item has no schedule.
    func setReminders(on isOn: Bool, for itemID: ItemID) async throws(StorageError) -> Schedule? {
        let store = try open()
        guard var schedule = try await store.schedules(of: itemID).first else { return nil }
        guard schedule.isEnabled != isOn else { return schedule }
        schedule.isEnabled = isOn
        try await store.save(schedule)
        return schedule
    }

    /// Archives or restores the item. The records stay (T08). It returns the item and its schedule, if any.
    func setArchived(
        _ isArchived: Bool,
        for itemID: ItemID
    ) async throws(StorageError) -> (item: Item, schedule: Schedule?)? {
        let store = try open()
        guard var item = try await store.item(id: itemID) else { return nil }
        if item.isArchived != isArchived {
            item.isArchived = isArchived
            try await store.save(item)
        }
        return (item, try await store.schedules(of: itemID).first)
    }

    /// Deletes the item with its schedules and its records, in one transaction (D033). It returns the IDs of
    /// the deleted schedules and of their versions, or `nil` when the store has no such item.
    func deleteItem(
        _ itemID: ItemID
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        try await open().deleteItem(itemID)
    }
}
