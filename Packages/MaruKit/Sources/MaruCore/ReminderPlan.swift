import Foundation

/// What a reminder says (spec 8.2, D029). The text is fixed when the app registers the request,
/// and nothing reads the database at delivery time. So it never says that a dose is not taken.
///
/// The notification target turns it into the text of the system. The engines compare that text
/// with the text of the pending request, so a new name, setting, or language replaces the request.
/// It holds no clock time: the system shows the delivery time on every notification.
public struct ReminderContent: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The repeating reminder at the slot time.
        case due
        /// The optional follow-up after the slot time (D021).
        case again
    }

    public let kind: Kind
    /// The names of the items, in the order of the schedules. `nil` when the user hides the names.
    public let names: [String]?
    /// The request has the "Taken" action, because it stands for exactly one item at its time (spec 8.3, D034).
    public let hasTakenAction: Bool

    public init(kind: Kind, names: [String]?, hasTakenAction: Bool = false) {
        self.kind = kind
        self.names = names
        self.hasTakenAction = hasTakenAction
    }
}

/// The text that the system shows for a request.
public struct ReminderText: Hashable, Sendable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

/// When a repeating reminder fires: a wall-clock time, on every day or on one weekday.
///
/// It has no instant. The system matches the components on its own calendar, also on the day of a clock change.
/// So the engine does not choose a fire time for a local time that a clock change removes or repeats (spec 8.5).
public struct ReminderTrigger: Hashable, Sendable {
    public let time: WallClockTime
    /// `nil` means every day.
    public let weekday: Weekday?
    /// `nil` means the time zone of the device. The reminder then follows the device to another zone.
    public let timeZone: NamedTimeZone?

    /// The components that a repeating calendar trigger of the system matches.
    public var dateComponents: DateComponents {
        var components = DateComponents()
        components.timeZone = timeZone?.systemZone
        components.hour = time.hour
        components.minute = time.minute
        // The calendar counts from Sunday = 1. `Weekday` counts from Monday = 1.
        components.weekday = weekday.map { $0.rawValue % 7 + 1 }
        return components
    }
}

/// One repeating request for the notification system.
public struct ReminderRequest: Hashable, Sendable {
    public static let seriesIDKey = "seriesID"
    public static let scheduleRevisionKey = "scheduleRevision"

    public let identifier: String
    public let trigger: ReminderTrigger
    public let content: ReminderContent
    /// The series ID and the schedule revision. A repeating request fires on many dates,
    /// so it never holds the ID of one occurrence (spec 8.3).
    public let userInfo: [String: String]
}

/// One wall-clock time in one time zone rule, with every slot that the plan has at that time (spec 7.1, 8.1).
/// The spec calls it `NotificationSeries`.
///
/// The slots of a series share its requests, so two items at 08:00 give one reminder and not two.
/// A series that fires on every day with the same text has one request. Another series has one request
/// for each weekday, because one calendar trigger matches one weekday and has one text.
///
/// The ID comes from the time zone rule and the time, and each request identifier comes from the ID
/// and the day. So the same plan always gives the same identifiers, and a request that is added again
/// replaces the pending one. A series has no stored state.
public struct ReminderSeries: Hashable, Sendable {
    /// Every identifier of a series request starts with this text. The engine removes only such requests.
    public static let identifierPrefix = "series|"

    public struct Member: Hashable, Sendable {
        public let slotID: ScheduleSlotID
        public let scheduleVersionID: ScheduleVersionID
    }

    /// One item of the series and the weekdays on which it reminds at this time.
    struct Entry: Hashable, Sendable {
        let itemID: ItemID
        let name: String
        let weekdays: Set<Weekday>
    }

    public let id: String
    /// `nil` means the time zone of the device.
    public let timeZone: NamedTimeZone?
    public let time: WallClockTime
    /// The weekdays of all members together.
    public let weekdays: Set<Weekday>
    public let members: [Member]
    /// Changes when a member joins, leaves, or gets another schedule version. A tap on a delivered
    /// reminder compares it with the plan of now, to see that the reminder is from an older plan (spec 8.3).
    public let revision: String
    /// The items, in the order of the schedules.
    let entries: [Entry]
    /// `false` when the user hides the names (D029).
    let showsNames: Bool

    init(
        timeZone: NamedTimeZone?,
        time: WallClockTime,
        weekdays: Set<Weekday>,
        members: [Member],
        entries: [Entry] = [],
        showsNames: Bool = true
    ) {
        self.id = Self.identifierPrefix + (timeZone?.identifier ?? "device")
            + String(format: "|%02d:%02d", time.hour, time.minute)
        self.timeZone = timeZone
        self.time = time
        self.weekdays = weekdays
        self.members = members
        self.entries = entries
        self.showsNames = showsNames
        // FNV-1a over the members in a fixed order. It only tells two member lists apart. It protects nothing.
        let text = members.map { "\($0.slotID.rawValue)=\($0.scheduleVersionID.rawValue)" }.sorted().joined(separator: ";")
        let hash = text.utf8.reduce(0xcbf2_9ce4_8422_2325 as UInt64) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
        self.revision = String(hash, radix: 16)
    }

    /// One daily request when the series reminds on every day with the same text. Otherwise one request
    /// for each weekday, because a request has one fixed text, and a day must not name an item that it does not have.
    public var requests: [ReminderRequest] {
        var contents = Dictionary(uniqueKeysWithValues: weekdays.map { ($0, content(on: $0)) })
        // With the names hidden, the text is the same on each day, and the series keeps its one daily request (D029).
        // That request has the action only when each of its days has exactly one item (D034).
        if !showsNames, Set(contents.values).count > 1 {
            contents = contents.mapValues { _ in ReminderContent(kind: .due, names: nil) }
        }
        let daily = weekdays.count == Weekday.allCases.count && Set(contents.values).count == 1
        let days: [Weekday?] = daily ? [nil] : weekdays.sorted()
        return days.map { weekday in
            ReminderRequest(
                identifier: id + "|" + (weekday.map { String($0.rawValue) } ?? "daily"),
                trigger: ReminderTrigger(time: time, weekday: weekday, timeZone: timeZone),
                content: weekday.map { contents[$0]! } ?? contents[.monday]!,
                userInfo: [ReminderRequest.seriesIDKey: id, ReminderRequest.scheduleRevisionKey: revision]
            )
        }
    }

    /// The content of the series on one weekday: each item that reminds on that day, once.
    /// A day with exactly one item has the "Taken" action (D034).
    private func content(on weekday: Weekday) -> ReminderContent {
        var seen = Set<ItemID>()
        let names = entries.filter { $0.weekdays.contains(weekday) && seen.insert($0.itemID).inserted }.map(\.name)
        return ReminderContent(kind: .due, names: showsNames ? names : nil, hasTakenAction: names.count == 1)
    }
}

/// Why a saved schedule has no complete reminder in the system.
public enum ReminderProblem: Hashable, Sendable {
    /// The app did not ask for the notification permission yet.
    case permissionNotAsked
    /// Notifications are off for the app. The user can still record (spec 2.2, T13, T14).
    case permissionDenied
    /// The system does not hold a request of the schedule. Another run tries again.
    case notRegistered
    /// The first version of the schedule starts on a later date. The first run on or after that date registers it.
    case notStarted
    /// The plan has more repeating requests than `ReminderPlan.requestBudget`.
    case overLimit
    /// The schedule has an end date. A repeating request has no end, so the engine registers none (spec 8.4).
    case endDate
}

/// The reminders that the saved plan asks for (spec 8.1).
///
/// It is a value of the items, the schedules, and the date of the run. The clock and the device time zone
/// are inputs. It reads no system state.
public struct ReminderPlan: Hashable, Sendable {
    /// The system keeps at most 64 pending local notifications for one app.
    public static let systemLimit = 64
    /// The requests that the series can use. The other 16 stay free for one-time requests (spec 8.4).
    public static let requestBudget = 48

    /// What one schedule needs from the system.
    public enum Need: Hashable, Sendable {
        /// The reminders are off, or the item is archived (T07, T08).
        case nothing
        /// The identifiers of the requests that remind for the schedule.
        case requests(Set<String>)
        /// The engine registers no complete reminder for the schedule.
        case blocked(ReminderProblem)
    }

    /// The series that the system gets, in the order of the schedules.
    public let series: [ReminderSeries]
    /// Every schedule of the plan. An item with no schedule is a list-only item and has no entry (T02).
    public let needs: [ScheduleID: Need]

    public var requests: [ReminderRequest] {
        series.flatMap(\.requests)
    }

    /// Compiles the plan. A schedule reminds only while it is enabled and its item is not archived.
    ///
    /// The series follow the version of each schedule that is in force at `now`, by the rule of
    /// `Schedule.version(on:)`, as the occurrences of today do. The date is the calendar date in the time zone
    /// of the version. A repeating request has no start date, so a version that starts later replaces
    /// the reminder at the first run on or after its date, and not before.
    ///
    /// A series that does not fit in the budget gets no request, and each of its schedules is `.blocked(.overLimit)`.
    /// The series get their requests in the order in which the schedules first use them.
    ///
    /// - Parameters:
    ///   - schedules: In a stable order, for example the order of the first save.
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the date of the versions that follow it.
    ///   - privacy: Whether the text names the items (D029).
    public init(
        items: [Item],
        schedules: [Schedule],
        now: Date,
        deviceTimeZone: NamedTimeZone,
        privacy: ReminderPrivacy = .showNames,
        requestBudget: Int = ReminderPlan.requestBudget
    ) {
        struct Key: Hashable {
            let timeZone: NamedTimeZone?
            let time: WallClockTime
        }
        /// `nil` means the time zone of the device.
        func seriesTimeZone(of version: ScheduleVersion) -> NamedTimeZone? {
            switch version.timeZonePolicy {
            case let .fixed(zone): zone
            case .followsDevice: nil
            }
        }
        let activeItems = Dictionary(
            items.filter { !$0.isArchived }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        var keys: [Key] = []
        var weekdays: [Key: Set<Weekday>] = [:]
        var members: [Key: [ReminderSeries.Member]] = [:]
        var entries: [Key: [ReminderSeries.Entry]] = [:]
        var keysOfSchedule: [ScheduleID: [Key]] = [:]
        var needs: [ScheduleID: Need] = [:]
        for schedule in schedules {
            guard schedule.isEnabled, let item = activeItems[schedule.itemID], !schedule.versions.isEmpty else {
                needs[schedule.id] = .nothing
                continue
            }
            guard schedule.endDate == nil else {
                needs[schedule.id] = .blocked(.endDate)
                continue
            }
            let inForce = schedule.versions.last {
                $0.effectiveFrom <= LocalDate(now, in: seriesTimeZone(of: $0) ?? deviceTimeZone)
            }
            guard let version = inForce else {
                needs[schedule.id] = .blocked(.notStarted)
                continue
            }
            let timeZone = seriesTimeZone(of: version)
            for slotTime in version.slotTimes {
                let key = Key(timeZone: timeZone, time: slotTime.time)
                if members[key] == nil { keys.append(key) }
                weekdays[key, default: []].formUnion(version.weeklyRule.weekdays)
                members[key, default: []].append(.init(slotID: slotTime.slotID, scheduleVersionID: version.id))
                entries[key, default: []].append(
                    .init(itemID: item.id, name: item.name, weekdays: version.weeklyRule.weekdays)
                )
                keysOfSchedule[schedule.id, default: []].append(key)
            }
        }
        var kept: [Key: ReminderSeries] = [:]
        var used = 0
        for key in keys {
            let series = ReminderSeries(
                timeZone: key.timeZone,
                time: key.time,
                weekdays: weekdays[key]!,
                members: members[key]!,
                entries: entries[key] ?? [],
                showsNames: privacy == .showNames
            )
            let count = series.requests.count
            guard used + count <= requestBudget else { continue }
            used += count
            kept[key] = series
        }
        for (scheduleID, keys) in keysOfSchedule {
            let series = keys.compactMap { kept[$0] }
            needs[scheduleID] = series.count == keys.count
                ? .requests(Set(series.flatMap(\.requests).map(\.identifier)))
                : .blocked(.overLimit)
        }
        self.series = keys.compactMap { kept[$0] }
        self.needs = needs
    }
}
