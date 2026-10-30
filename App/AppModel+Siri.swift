import Foundation
import MaruCore
import MaruDatabase

/// The next open doses of today, for Siri (D108).
struct SiriNextDoses: Sendable {
    let part: DayPart
    /// The first planned time of the open doses of the part of the day, as an instant.
    let time: Date
    let timeZone: TimeZone
    /// The open doses of the part of the day, in the order of Today.
    let doses: [(name: String, amount: String?)]
}

/// What "What do I take next" answers (D108).
enum SiriNext: Sendable {
    case next(SiriNextDoses)
    /// Every planned dose of today has a record, taken or skipped.
    case allDone
    /// Today has no planned dose.
    case nothingPlanned
}

/// The open doses of the part of the day of the clock, which "Record my doses" records (D108).
struct SiriDueDoses: Sendable {
    let entries: [TodaySnapshot.Entry]
    /// The generation of the data of the read (D040).
    let generation: Int
    /// An instant before the read. The store refuses a dose whose item changed its owner after it (D123).
    let readAt: Date
    /// The read had two or more active members, so the doses are of the one member that the user chose (D129).
    let namesMember: Bool

    var names: [String] { entries.map(\.look.labelledName) }
}

/// Why `siriDueDoses` gives no doses.
enum SiriDueDosesError: Error {
    /// The Family has two or more active members, and the user did not choose one yet (D123, D129).
    case severalMembers
}

extension AppModel {
    /// Siri offers the active items by name. The system reads them again only when an item or a name changes (D108).
    func updateShortcutItems(_ list: [ListEntry]) {
        let names = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0.owner?.label($0.name) ?? $0.name) })
        guard names != shortcutItemNames else { return }
        shortcutItemNames = names
        MaruShortcuts.updateAppShortcutParameters()
    }

    /// The active items, so Siri can pick one by name (D108). It reads no record.
    func siriItems() async throws(StorageError) -> [ListEntry] {
        let list = try await store.snapshot(at: Date(), deviceTimeZone: nil, generation: dataGeneration).list
        return showsNamesInReminders ? list : list.map { entry in
            var hidden = entry
            hidden.owner = nil
            return hidden
        }
    }

    /// The newest taken dose of an active item (D108). It records nothing.
    func siriLastDose(of itemID: ItemID) async throws(StorageError) -> LastDose? {
        analytics.markUsed(.siri)
        return try await store.lastDose(of: itemID)
    }

    /// The next open doses of today (D108). It records nothing.
    ///
    /// It takes the same part of the day as the small "Today" widget: the first part from the clock on that has an
    /// open dose, else the first earlier part with an open dose (D048). A dose with an event that the store did not
    /// confirm is open (D014).
    func siriNext() async throws(StorageError) -> SiriNext {
        analytics.markUsed(.siri)
        let (day, timeZone, _) = try await freshToday()
        let open = day.groups.compactMap { group -> TodaySnapshot.Group? in
            let entries = group.entries.filter { !isDone($0) }
            return entries.isEmpty ? nil : TodaySnapshot.Group(part: group.part, entries: entries)
        }
        let clock = DayPart.allCases.firstIndex(of: Self.clockPart(at: Date(), in: timeZone))!
        guard let group = open.first(where: { DayPart.allCases.firstIndex(of: $0.part)! >= clock }) ?? open.first else {
            return day.entries.isEmpty ? .nothingPlanned : .allDone
        }
        return .next(SiriNextDoses(
            part: group.part,
            time: group.entries.map { $0.occurrence.timeZone.resolve($0.occurrence.plannedTime, on: $0.occurrence.plannedDate).earliestInstant }.min()!,
            timeZone: timeZone,
            doses: group.entries.map { ($0.look.labelledName, $0.amount) }
        ))
    }

    /// The open doses of the part of the day of the clock (D108). It records nothing. A dose with an event that the store
    /// did not confirm, or with a record transaction that runs, is left out: it goes again only from Today (D014).
    ///
    /// With two or more active members it needs `member`, else it throws `SiriDueDosesError.severalMembers`: one confirmation must
    /// not record a dose for another member (D123). With `member` it gives only the doses of the items of that member now (D129).
    func siriDueDoses(for member: PersonID?) async throws -> SiriDueDoses {
        analytics.markUsed(.siri)
        let generation = dataGeneration
        // Before the read, so an owner change during the read refuses the record (D123).
        let readAt = Date()
        let (day, timeZone, activeMembers) = try await freshToday()
        // The members come from the read of the doses, after its items: a member that comes back during the read counts (D123).
        guard activeMembers < 2 || member != nil else { throw SiriDueDosesError.severalMembers }
        let part = Self.clockPart(at: Date(), in: timeZone)
        // The owner comes from the same read. An owner change after `readAt` refuses the record in the transaction (D123).
        let entries = day.groups.first { $0.part == part }?.entries.filter {
            $0.isOpen && today.pending[$0.id] == nil && !today.inFlight.contains($0.id)
                && (member == nil || $0.look.personID == member)
        } ?? []
        return SiriDueDoses(entries: entries, generation: generation, readAt: readAt, namesMember: activeMembers >= 2)
    }

    /// Records the doses of `due` as taken now, in one record transaction (D108). `true` only after the commit (spec 7.2).
    ///
    /// It uses the checks of the widget and the Watch (D048, D071): each event revises the record that Siri read, so a change in
    /// between makes the store reject it (T18). `requiresCurrentPlan` checks the active item, the slot, the schedule version,
    /// and the day of now in the transaction. A restore after the read refuses the record (D040). After the commit it waits for
    /// the reminder run (D047), because the system can suspend the process after Siri answers.
    func recordFromSiri(_ due: SiriDueDoses) async -> Bool {
        let now = Date()
        let events = due.entries.map { entry in
            var event = PendingEvent(
                event: entry.record.nextEvent(.taken, at: now, source: .app),
                scheduleVersionID: entry.occurrence.scheduleVersionID
            )
            event.requiresCurrentPlan = true
            event.listedAt = due.readAt
            return event
        }
        let confirmed = Dictionary(uniqueKeysWithValues: due.entries.map { ($0.id, $0.record) })
        guard await commitAndWait(events, generation: due.generation, confirmed: confirmed) else { return false }
        if let deviceTimeZone = NamedTimeZone(device: .current, at: Date()) {
            await waitForReminders(deviceTimeZone: deviceTimeZone)
        }
        return true
    }

    /// A new read of today, with the confirmed record of each running transaction. A device time zone with no region
    /// name gives no today (spec 2), so it is `unavailable`. Siri and the Live Activity (D110) use it.
    /// `activeMembers` is the number of active members of the Family in the same read (D121).
    func freshToday() async throws(StorageError) -> (day: TodaySnapshot, timeZone: TimeZone, activeMembers: Int) {
        let now = Date()
        let generation = dataGeneration
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now),
              let timeZone = TimeZone(identifier: deviceTimeZone.identifier)
        else { throw StorageError.unavailable }
        let snapshot = try await store.snapshot(at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        guard var day = snapshot.today else { throw StorageError.unavailable }
        // A restore replaced the data during the read.
        guard generation == dataGeneration else { throw StorageError.replaced }
        day.apply(heldRecords)
        return (day, timeZone, snapshot.people.filter { !$0.isArchived }.count)
    }

    /// The part of the day of the clock at `date`.
    private static func clockPart(at date: Date, in timeZone: TimeZone) -> DayPart {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return DayPart(try! WallClockTime(hour: calendar.component(.hour, from: date), minute: 0))
    }
}

extension AppStore {
    /// Every member of the Family. See `LocalStore.people()`.
    func people() async throws(StorageError) -> [Person] {
        try await open().people()
    }

    /// The newest taken dose of an active item. See `LocalStore.lastDose(of:)`.
    func lastDose(of itemID: ItemID) async throws(StorageError) -> LastDose? {
        try await open().lastDose(of: itemID)
    }
}
