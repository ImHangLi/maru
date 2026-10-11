import Foundation

/// How long after the slot time the optional follow-up comes (D021). The setting is off by default (spec 4),
/// and "off" is `nil`, not a case, so the app cannot pick a delay for the user.
public enum FollowUpDelay: Int, CaseIterable, Hashable, Sendable {
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60
}

/// One slot time on one date in one time zone: every occurrence of one series rule that fires at the same instant.
///
/// A follow-up belongs to such a group and not to one occurrence, as a series reminder does. So two items
/// at 08:00 give one follow-up, and it comes while one of them is still open.
///
/// The group uses the zone in which the occurrence resolves, not only the rule of its series. Two occurrences
/// of a series that follows the device can resolve in two zones, for example a stored occurrence that keeps
/// its zone after an undo. They fire at two instants, so they get two groups.
public struct FollowUpGroup: Hashable, Sendable {
    /// The zone of the series rule. `nil` means the time zone of the device.
    public let seriesTimeZone: NamedTimeZone?
    /// The zone in which the occurrences resolve. For a fixed rule it is the zone of the rule.
    public let timeZone: NamedTimeZone
    public let plannedDate: LocalDate
    public let time: WallClockTime

    /// The ID of the series that reminds at this time. A tap on a follow-up uses it with `plannedDate` (spec 8.3).
    public var seriesID: String {
        ReminderSeries.identifierPrefix + (seriesTimeZone?.identifier ?? "device")
            + String(format: "|%02d:%02d", time.hour, time.minute)
    }

    /// `followup|<zone>|<YYYY-MM-DD>|<HH:MM>` for a fixed rule, and `followup|device@<zone>|<YYYY-MM-DD>|<HH:MM>`
    /// for a rule that follows the device. It holds no item name, no dose, and no ID (spec 10),
    /// so the removal ledger can keep it outside the health database.
    public var identifier: String {
        FollowUpRequest.identifierPrefix + (seriesTimeZone == nil ? "device@" : "") + timeZone.identifier
            + "|" + dateText + String(format: "|%02d:%02d", time.hour, time.minute)
    }

    var dateText: String {
        String(format: "%04d-%02d-%02d", plannedDate.year, plannedDate.month, plannedDate.day)
    }
}

/// One one-time request for the notification system. It fires once, at one instant.
public struct FollowUpRequest: Hashable, Sendable {
    /// Every identifier of a follow-up request starts with this text. The follow-up engine removes only such
    /// requests. The series engine removes them only to make room for a series request.
    public static let identifierPrefix = "followup|"
    public static let plannedDateKey = "plannedDate"
    /// The fire instant in ISO 8601 UTC. A new delay or a new device time zone changes it,
    /// so the engine then replaces the pending request.
    public static let fireTimeKey = "fireTime"
    /// The ID of the one item of a request with the "Taken" action. The action records only a dose of this item (D034).
    public static let itemIDKey = "itemID"
    /// The ID of the schedule version of the one dose of a request with the "Taken" action.
    /// The action records only a dose with this version (D034).
    public static let scheduleVersionIDKey = "scheduleVersionID"

    public let identifier: String
    /// The items of the group that are open when the request is set (D029).
    /// Each record refreshes the follow-ups, so a recorded item leaves the text, and a closed group loses its request.
    /// The request has the "Taken" action when the group has exactly one item, open or not (D034).
    public let content: ReminderContent
    /// The series ID, the plan date, and the fire instant. The series ID and the plan date give a tap
    /// the candidate occurrences (spec 8.3). A request with the "Taken" action also has the ID of its item
    /// and of its schedule version, and no name. They stay in the notification system and are never logged (spec 10).
    public let userInfo: [String: String]
    /// The exact fire instant. The system gets the interval from the time of the add to this instant,
    /// because calendar components cannot name one instant of a local time that a clock change repeats.
    public let fireDate: Date
}

/// The follow-ups that the saved plan, the records, and the setting ask for (D021).
///
/// It is a value of its inputs and reads no system state.
public struct FollowUpPlan: Hashable, Sendable {
    /// Follow-ups come for the slot times of the next seven days. The app sets them again at each run,
    /// so they stop when the app does not run for seven days. The series reminders continue.
    public static let days = 7

    /// Every request that the plan wants, nearest first. The engine sets as many as the system has room for.
    public let requests: [FollowUpRequest]
    /// The text of each group that still has an open occurrence, by identifier. A delivered follow-up
    /// of another group, or with another text, is removed.
    public let openGroups: [String: ReminderContent]

    /// - Parameters:
    ///   - delay: `nil` when the setting is off. The plan then has no request and no open group,
    ///     so the engine removes every pending and every delivered follow-up.
    ///   - reminders: The series plan of the same read. A follow-up comes only for a schedule whose
    ///     series reminder is set up, so a paused, archived, ended, or blocked schedule gets none.
    ///   - stored: The stored occurrences on `OccurrenceGeneration.candidateDates`.
    ///   - closed: The keys of the occurrences that have a current taken or skipped event.
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the schedule versions that follow it.
    ///   - privacy: Whether the text names the open items (D029).
    public init(
        delay: FollowUpDelay?,
        reminders: ReminderPlan,
        items: [Item],
        schedules: [Schedule],
        stored: [StoredOccurrence],
        closed: Set<OccurrenceKey>,
        now: Date,
        deviceTimeZone: NamedTimeZone,
        privacy: ReminderPrivacy = .showNames
    ) {
        guard let delay else {
            requests = []
            openGroups = [:]
            return
        }
        let reminding = schedules.filter {
            if case .requests = reminders.needs[$0.id] { true } else { false }
        }
        let scheduleOfSlot = Dictionary(
            reminding.flatMap { schedule in schedule.slots.map { ($0.id, schedule) } },
            uniquingKeysWith: { first, _ in first }
        )
        let order = Dictionary(reminding.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
        let itemOfID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var open: [FollowUpGroup: Date] = [:]
        var names: [FollowUpGroup: [(order: Int, itemID: ItemID, name: String)]] = [:]
        /// Every item of a group with its schedule versions, also an item with a record.
        /// A group of exactly one item in one version gets the "Taken" action (D034).
        var members: [FollowUpGroup: [ItemID: Set<ScheduleVersionID>]] = [:]
        func add(_ key: OccurrenceKey, time: WallClockTime, timeZone: NamedTimeZone, versionID: ScheduleVersionID) {
            guard let schedule = scheduleOfSlot[key.slotID] else { return }
            let policy = schedule.versions.first { $0.id == versionID }?.timeZonePolicy ?? .fixed(timeZone)
            let seriesZone: NamedTimeZone? = switch policy {
            case let .fixed(zone): zone
            case .followsDevice: nil
            }
            let group = FollowUpGroup(seriesTimeZone: seriesZone, timeZone: timeZone, plannedDate: key.plannedDate, time: time)
            members[group, default: [:]][schedule.itemID, default: []].insert(versionID)
            guard !closed.contains(key) else { return }
            // A local time that a clock change removes or repeats uses its first instant (T25).
            // The zone, the date, and the time give one instant, so every member of a group has it.
            open[group] = timeZone.resolve(time, on: key.plannedDate).earliestInstant
                .addingTimeInterval(Double(delay.rawValue * 60))
            if let item = itemOfID[schedule.itemID] {
                names[group, default: []].append((order[schedule.id] ?? 0, item.id, item.name))
            }
        }
        /// The open items of a group in the order of the schedules, each once. `nil` when the user hides the names.
        func openNames(of group: FollowUpGroup) -> [String]? {
            guard privacy == .showNames, let all = names[group], !all.isEmpty else { return nil }
            var seen = Set<ItemID>()
            return all.enumerated()
                .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
                .map(\.element)
                .filter { seen.insert($0.itemID).inserted }
                .map(\.name)
        }
        // The occurrence window (yesterday to tomorrow) uses the stored occurrences, as the Today screen does.
        // A stored occurrence with an intake event keeps its time after a schedule edit (D019), so its follow-up
        // stays at that time.
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
            for date in (-2...(Self.days + 1)).map({ today.adding(days: $0) }) {
                for planned in schedule.plannedOccurrences(on: date, deviceTimeZone: deviceTimeZone)
                where !covered.contains(planned.key) {
                    add(planned.key, time: planned.plannedTime, timeZone: planned.timeZone, versionID: planned.scheduleVersionID)
                }
            }
        }
        /// The one item and its one schedule version, for a group that gets the "Taken" action.
        func single(of group: FollowUpGroup) -> (itemID: ItemID, versionID: ScheduleVersionID)? {
            guard let all = members[group], all.count == 1, let (itemID, versions) = all.first, versions.count == 1 else {
                return nil
            }
            return (itemID, versions.first!)
        }
        let contents = Dictionary(
            open.keys.map { group in
                let content = ReminderContent(
                    kind: .again, names: openNames(of: group), hasTakenAction: single(of: group) != nil
                )
                return (group.identifier, content)
            },
            uniquingKeysWith: { first, _ in first }
        )
        openGroups = contents
        let end = now.addingTimeInterval(Double(Self.days) * 86_400)
        requests = open
            .filter { $0.value > now && $0.value <= end }
            .sorted { ($0.value, $0.key.identifier) < ($1.value, $1.key.identifier) }
            .map { group, fireDate in
                var userInfo = [
                    ReminderRequest.seriesIDKey: group.seriesID,
                    FollowUpRequest.plannedDateKey: group.dateText,
                    FollowUpRequest.fireTimeKey: fireDate.formatted(.iso8601),
                ]
                // The action records only the dose that the request was made for, also after a plan change (D034).
                if let single = single(of: group) {
                    userInfo[FollowUpRequest.itemIDKey] = single.itemID.rawValue.uuidString
                    userInfo[FollowUpRequest.scheduleVersionIDKey] = single.versionID.rawValue.uuidString
                }
                return FollowUpRequest(
                    identifier: group.identifier, content: contents[group.identifier]!, userInfo: userInfo, fireDate: fireDate
                )
            }
    }
}
