import Foundation

/// The doses of the schedules that remind, grouped by one slot time on one date in one time zone (D039, D047, D079).
///
/// The follow-ups and the alarms share this grouping. Each group is the set of items that one reminder time covers.
/// It is a value of its inputs and reads no system state.
struct DoseGroups {
    /// An item with an open dose in a group.
    struct OpenItem {
        /// The position of its schedule. The text lists the items in this order.
        let order: Int
        let itemID: ItemID
        let name: String?
        /// The dose itself: its slot and the schedule version that it has. A group action records exactly these (D090).
        let slotID: ScheduleSlotID
        let versionID: ScheduleVersionID
    }

    /// The instant of the slot time of each group that has an open dose.
    private(set) var slotInstants: [FollowUpGroup: Date] = [:]
    private(set) var open: [FollowUpGroup: [OpenItem]] = [:]
    /// Every item of a group with its schedule versions, also an item with a record.
    /// A group of exactly one item in one version gets the "Taken" action (D034).
    private var members: [FollowUpGroup: [ItemID: Set<ScheduleVersionID>]] = [:]
    /// The instant of every slot time of each item, with a record or not.
    private(set) var doses: [ItemID: Set<Date>] = [:]

    /// - Parameters:
    ///   - reminding: The schedules whose reminder the plan sets up, in a stable order.
    ///   - stored: The stored occurrences on `OccurrenceGeneration.candidateDates`.
    ///   - closed: The keys of the occurrences that have a current taken or skipped event.
    ///   - days: How many days after today the groups reach.
    init(
        reminding: [Schedule],
        items: [Item],
        stored: [StoredOccurrence],
        closed: Set<OccurrenceKey>,
        now: Date,
        deviceTimeZone: NamedTimeZone,
        days: Int = FollowUpPlan.days
    ) {
        let scheduleOfSlot = Dictionary(
            reminding.flatMap { schedule in schedule.slots.map { ($0.id, schedule) } },
            uniquingKeysWith: { first, _ in first }
        )
        let order = Dictionary(reminding.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let itemOfID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        func add(_ key: OccurrenceKey, time: WallClockTime, timeZone: NamedTimeZone, versionID: ScheduleVersionID) {
            guard let schedule = scheduleOfSlot[key.slotID] else { return }
            let policy = schedule.versions.first { $0.id == versionID }?.timeZonePolicy ?? .fixed(timeZone)
            let seriesZone: NamedTimeZone? = switch policy {
            case let .fixed(zone): zone
            case .followsDevice: nil
            }
            let group = FollowUpGroup(seriesTimeZone: seriesZone, timeZone: timeZone, plannedDate: key.plannedDate, time: time)
            // A local time that a clock change removes or repeats uses its first instant (T25).
            // The zone, the date, and the time give one instant, so every member of a group has it.
            let instant = timeZone.resolve(time, on: key.plannedDate).earliestInstant
            members[group, default: [:]][schedule.itemID, default: []].insert(versionID)
            doses[schedule.itemID, default: []].insert(instant)
            guard !closed.contains(key) else { return }
            slotInstants[group] = instant
            open[group, default: []].append(
                OpenItem(
                    order: order[schedule.id] ?? 0, itemID: schedule.itemID, name: itemOfID[schedule.itemID]?.name,
                    slotID: key.slotID, versionID: versionID
                )
            )
        }
        // The occurrence window (yesterday to tomorrow) uses the stored occurrences, as the Today screen does.
        // A stored occurrence with a record keeps its time after a schedule edit (D019, D095). An open one follows the plan.
        let window = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone)
            .outcome(items: items, schedules: reminding, stored: stored)
            .occurrences
        for occurrence in window {
            add(occurrence.key, time: occurrence.plannedTime, timeZone: occurrence.timeZone, versionID: occurrence.scheduleVersionID)
        }
        // The dates after the window have no stored occurrence yet, so they come from the schedule.
        let covered = Set(stored.map(\.occurrence.key) + window.map(\.key))
        // Yesterday in the earliest zone to the last day of the window in the latest zone.
        let today = LocalDate(now, in: .utc)
        for schedule in reminding {
            for date in (-2...(days + 1)).map({ today.adding(days: $0) }) {
                for planned in schedule.plannedOccurrences(on: date, deviceTimeZone: deviceTimeZone)
                where !covered.contains(planned.key) {
                    add(planned.key, time: planned.plannedTime, timeZone: planned.timeZone, versionID: planned.scheduleVersionID)
                }
            }
        }
    }

    /// The open items of a group in the order of the schedules, each once.
    func orderedOpenItems(of group: FollowUpGroup) -> [OpenItem] {
        var seen = Set<ItemID>()
        return (open[group] ?? []).enumerated()
            .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
            .map(\.element)
            .filter { seen.insert($0.itemID).inserted }
    }

    /// The open doses of `items` in a group, as the text of `FollowUpRequest.membersKey`: `<slot ID>=<schedule version ID>`
    /// entries in a fixed order. An item with two slots at the time has two entries. A group action records exactly these doses (D090).
    func membersText(of group: FollowUpGroup, items: Set<ItemID>) -> String {
        (open[group] ?? []).filter { items.contains($0.itemID) }
            .map { "\($0.slotID.rawValue.uuidString)=\($0.versionID.rawValue.uuidString)" }
            .sorted().joined(separator: ",")
    }

    /// The one item and its one schedule version, for a group that gets the "Taken" action.
    func single(of group: FollowUpGroup) -> (itemID: ItemID, versionID: ScheduleVersionID)? {
        guard let all = members[group], all.count == 1, let (itemID, versions) = all.first, versions.count == 1 else {
            return nil
        }
        return (itemID, versions.first!)
    }
}
