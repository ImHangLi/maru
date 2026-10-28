import Foundation
import MaruCore
import MaruDatabase

/// What the edit screen needs from the store when it opens.
struct EditorContext: Sendable {
    /// `nil` for a new item.
    let item: Item?
    let schedule: Schedule?
    /// Every member of the Family, archived or not (D121).
    let people: [Person]
    /// The color of a new item: the first one that no active item uses (D021).
    let newItemColor: ItemColor
    /// The times that the user already confirmed for an active supplement, from the earliest.
    let supplementTimes: [WallClockTime]
    /// The names of the user's other items, active items first. The name suggestions show them first (D038).
    let itemNames: [String]
    /// What a new item starts with for "Alarm" and "Remind Again": the last choice of the user in Settings (D085).
    let newItemReminders: NewItemReminders
}

extension EditorContext {
    /// The owner of a new item when the user chose none: "Me", or the first active member when "Me" is archived (D121).
    var defaultOwner: PersonID {
        let active = people.filter { !$0.isArchived }
        return (active.first { $0.kind == .me } ?? active.first ?? people[0]).id
    }

    /// The time at which the time wheel of a new supplement starts (spec 2.1): the earliest time that the user
    /// already confirmed for an active supplement, else 08:00. It counts only after "Add" (D032).
    var exampleTime: WallClockTime {
        supplementTimes.first ?? DayPart.morning.time(confirmed: [])
    }
}

extension AppStore {
    func editorContext(for itemID: ItemID?) async throws(StorageError) -> EditorContext {
        let store = try open()
        let items = try await store.items()
        var confirmed: Set<WallClockTime> = []
        for item in items where item.category == .supplement && !item.isArchived {
            for schedule in try await store.schedules(of: item.id) where schedule.isEnabled {
                confirmed.formUnion(schedule.versions.last?.slotTimes.map(\.time) ?? [])
            }
        }
        let item = itemID.flatMap { id in items.first { $0.id == id } }
        let schedule = if let item { try await store.schedules(of: item.id).first } else { Schedule?.none }
        return EditorContext(
            item: item,
            schedule: schedule,
            people: try await store.people(),
            newItemColor: .forNewItem(among: items),
            supplementTimes: confirmed.sorted(),
            itemNames: (items.filter { !$0.isArchived } + items.filter(\.isArchived))
                .filter { $0.id != itemID }
                .map(\.name),
            newItemReminders: .load()
        )
    }

    /// One transaction for the item and its schedule (spec 7.2). It returns after the commit.
    /// `generation` is the generation of the data that the edit screen read (D040).
    func save(_ item: Item, schedule: Schedule?, generation: Int) async throws(StorageError) {
        try await open().save(item, schedule: schedule, generation: generation)
    }

    /// One transaction for the new item, its schedule, and the archive of the old item (T06).
    func replace(_ oldItemID: ItemID, with item: Item, schedule: Schedule?, generation: Int) async throws(StorageError) {
        try await open().replace(oldItemID, with: item, schedule: schedule, generation: generation)
    }

    /// Makes the system reminders agree with the saved plan, and returns the state of one schedule (spec 8.1).
    ///
    /// - Parameter removesFollowUps: The change must also remove follow-ups, for example after an archive.
    ///   Then a follow-up removal that is open, or a failed follow-up refresh, confirms no state.
    func reconcile(
        scheduleID: ScheduleID,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        mayAskForPermission: Bool,
        removesFollowUps: Bool = false
    ) async throws -> ReminderState? {
        let outcome = try await reconcileReminders(
            at: now,
            deviceTimeZone: deviceTimeZone,
            mayAskForPermission: mayAskForPermission
        )
        let state = outcome.reminders.schedules[scheduleID]
        guard removesFollowUps, outcome.followUps?.removalPending != false else { return state }
        return switch state {
        case .off?, .scheduled?: .removalPending
        default: state
        }
    }

    /// One run of the notification queue after a delete. The plan no longer has the schedules of the item,
    /// so the run removes their reminders and their follow-ups. `true` when it confirmed every removal (spec 8.1).
    func reconcileAfterDelete(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> Bool {
        let outcome = try await reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
        return !outcome.reminders.removalPending && outcome.followUps?.removalPending == false
    }
}
