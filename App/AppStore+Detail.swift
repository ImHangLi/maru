import Foundation
import MaruCore
import MaruDatabase

/// What the detail page of one item shows (spec 3 P04).
struct ItemDetail: Equatable, Sendable {
    /// The day of the next dose of a plan that counts days (D036, D065).
    struct NextDose: Equatable, Sendable {
        let date: LocalDate
        /// 0 for today and 1 for tomorrow.
        let daysFromToday: Int
    }

    let item: Item
    /// `nil` for an item with no time (T02).
    let schedule: Schedule?
    /// `nil` for a plan that does not count days.
    let nextDose: NextDose?
    /// The strip of the last 7 days (D054). `nil` when the item had no planned dose and no taken as-needed dose.
    let week: HistoryItemWeek?
    /// The counts of the last 30 days (D091). `nil` when the item had no planned dose and no taken as-needed dose.
    let month: ItemSummary?
}

extension AppStore {
    /// The item, its schedule, its week strip, and its counts of 30 days. `nil` when the store has no such item.
    func detail(of itemID: ItemID, at now: Date, deviceTimeZone: NamedTimeZone?) async throws(StorageError) -> ItemDetail? {
        let store = try open()
        guard let item = try await store.item(id: itemID) else { return nil }
        let schedule = try await store.schedules(of: itemID).first
        // The same days and the same rule as the rows of History, so the strip cannot disagree with them (D054).
        let zone = deviceTimeZone ?? .utc
        let today = LocalDate(now, in: zone)
        let page = try await store.history(before: today.adding(days: 1), days: 30, deviceTimeZone: zone)
        let week = History.week(days: page.days, today: today, now: now).first { $0.itemID == itemID }
        let month = History.summary(days: page.days, today: today, now: now)[itemID]
        let nextDose = schedule.flatMap { schedule in
            deviceTimeZone.flatMap { Self.nextDose(of: schedule, at: now, deviceTimeZone: $0) }
        }
        return ItemDetail(item: item, schedule: schedule, nextDose: nextDose, week: week, month: month)
    }

    /// The first date from today on which a plan that counts days has a time that is still to come.
    /// It reads the plan and not the records: a dose of today that the user recorded early still counts
    /// until its time. So today after the last time of a plan of every second day gives the day after tomorrow.
    /// The search covers one full cycle from today, or from a start date that is still to come.
    private static func nextDose(of schedule: Schedule, at now: Date, deviceTimeZone: NamedTimeZone) -> ItemDetail.NextDose? {
        guard let version = schedule.versions.last, let cycle = version.dayCycle else { return nil }
        let zone = if case let .fixed(zone) = version.timeZonePolicy { zone } else { deviceTimeZone }
        let today = LocalDate(now, in: zone)
        let first = max(0, cycle.start.days(since: today))
        for days in first...first + cycle.daysOn + cycle.daysOff {
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
            // The time of the archive bounds the doses with no record that History keeps for the item (D091).
            item.archivedAt = isArchived ? Date() : nil
            try await store.save(item, generation: generation)
        }
        return (item, try await store.schedules(of: itemID).first)
    }

    /// Turns "Remind Again" on for one item (D091). It returns the schedule of the item, if any, or `nil` when the store
    /// has no such item. `generation` is the generation of the data that the model read (D040).
    func setFollowUp(
        _ setting: FollowUpSetting,
        for itemID: ItemID,
        at now: Date,
        generation: Int
    ) async throws(StorageError) -> Schedule? {
        let store = try open()
        guard var item = try await store.item(id: itemID) else { return nil }
        item.followUp = setting
        item.followUpChanged = now
        try await store.save(item, generation: generation)
        return try await store.schedules(of: itemID).first
    }

    /// Deletes the item with its schedules and its records, in one transaction (D033). It returns the IDs of
    /// the deleted schedules and of their versions, or `nil` when the store has no such item.
    /// After the commit, the photo file of the item goes too (D056).
    func deleteItem(
        _ itemID: ItemID,
        generation: Int
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        let store = try open()
        let photo = try await store.item(id: itemID)?.imageReference
        let deleted = try await store.deleteItem(itemID, generation: generation)
        if deleted != nil { ItemPhotos.remove(photo) }
        return deleted
    }
}
