import Foundation

/// What a reminder says (spec 8.2, D029). The text is fixed when the app registers the request,
/// and nothing reads the database at delivery time. So it never says that a dose is not taken.
///
/// The notification target turns it into the text of the system. The engines compare that text
/// with the text of the pending request, so a new name, setting, or language replaces the request.
/// It holds no clock time: the system shows the delivery time on every notification.
public struct ReminderContent: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// The first reminder at the slot time: a repeating request, or a dated request of a plan
        /// with a day cycle (D036, D065).
        case due
        /// The optional follow-up after the slot time (D021).
        case again
    }

    public let kind: Kind
    /// The names of the items, in the order of the schedules, each with its owner when the Family names owners (D123).
    /// `nil` when the user hides the names.
    public let names: [ReminderName]?
    /// How the request looks and acts: its actions and its level (D034, D090).
    public let presentation: ReminderPresentation

    public init(kind: Kind, names: [ReminderName]?, category: ReminderCategory = .snooze, level: ReminderLevel = .timeSensitive) {
        self.kind = kind
        self.names = names
        presentation = ReminderPresentation(category: category, level: level)
    }

    public var category: ReminderCategory { presentation.category }
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

/// When a reminder fires: a wall-clock time, on every day, on one weekday, or on one date.
///
/// It has no instant. The system matches the components on its own calendar, also on the day of a clock change.
/// So the engine does not choose a fire time for a local time that a clock change removes or repeats (spec 8.5).
public struct ReminderTrigger: Hashable, Sendable {
    public let time: WallClockTime
    /// `nil` means every day.
    public let weekday: Weekday?
    /// The one date of a dated request (D036). `nil` means that the request repeats.
    public let date: LocalDate?
    /// `nil` means the time zone of the device. The reminder then follows the device to another zone.
    public let timeZone: NamedTimeZone?

    /// A dated request fires one time. The system has no repeating trigger for a day cycle.
    public var repeats: Bool { date == nil }

    /// The components that a calendar trigger of the system matches.
    public var dateComponents: DateComponents {
        var components = DateComponents()
        components.timeZone = timeZone?.systemZone
        components.year = date?.year
        components.month = date?.month
        components.day = date?.day
        components.hour = time.hour
        components.minute = time.minute
        // The calendar counts from Sunday = 1. `Weekday` counts from Monday = 1.
        components.weekday = weekday.map { $0.rawValue % 7 + 1 }
        return components
    }
}

/// One request of a series for the notification system: a repeating request, or a dated request (D036).
public struct ReminderRequest: Hashable, Sendable {
    public static let seriesIDKey = "seriesID"
    public static let scheduleRevisionKey = "scheduleRevision"
    /// The latest owner change of the items that a request names, as seconds since 2001-01-01 UTC (D123). A request has it only
    /// when one of its items changed its owner. It holds no ID and no name. An action records nothing for an item whose owner
    /// changed after it, also when the system delivers the request after the change.
    public static let ownerChangedKey = "ownerChanged"

    /// The value of `ownerChangedKey` for the owner changes of the named items, or `nil` when none of them changed its owner.
    public static func ownerChangedText(of changes: [Date?]) -> String? {
        changes.compactMap { $0 }.max().map { String($0.timeIntervalSinceReferenceDate) }
    }

    /// Whether the owner of `item` changed after the request was made (D123). `text` is the value of `ownerChangedKey`.
    public static func ownerChanged(_ item: Item, after text: String?) -> Bool {
        guard let changed = item.ownerChangedAt else { return false }
        guard let made = text.flatMap(Double.init) else { return true }
        return changed.timeIntervalSinceReferenceDate > made
    }
    /// The plan date of a dated request, as `YYYY-MM-DD`. A repeating request does not have it.
    public static let dueDateKey = "dueDate"
    /// The slot IDs that a dated request still reminds for, separated by commas. A request has it only when
    /// a record closed a member before the time (D047). A repeating request does not have it.
    public static let openSlotsKey = "openSlots"

    public let identifier: String
    public let trigger: ReminderTrigger
    public let content: ReminderContent
    /// The series ID and the schedule revision. A repeating request fires on many dates,
    /// so it never holds the ID of one occurrence (spec 8.3). A dated request also has its plan date.
    public let userInfo: [String: String]
    /// The instant at which a dated request fires, as the plan computes it. `nil` for a repeating request.
    /// The engine uses it only to see that a request that is gone was delivered. The system gets the trigger.
    public let fireDate: Date?
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
///
/// A plan with a day cycle (every other day, every few days, or days with a pause after them) cannot use
/// a repeating trigger. So it gets dated series (D036, D065):
/// one series for one date, with the slots that are due at the time on that date, and one request that
/// fires one time. A dated series has only such slots. A slot with a weekly rule at the same time stays
/// in the repeating series, so a repeating request never names an item on a day when it is not due.
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
        /// The member of the item. A request that names doses of two or more members has no group action (D123).
        let personID: PersonID
        let ownerChangedAt: Date?
        /// The owner for the text. `nil` when the Family has one active member.
        let owner: DoseOwner?
        let weekdays: Set<Weekday>

        var reminderName: ReminderName { ReminderName(item: name, owner: owner) }
    }

    public let id: String
    /// `nil` means the time zone of the device.
    public let timeZone: NamedTimeZone?
    public let time: WallClockTime
    /// The weekdays of all members together. Empty for a dated series.
    public let weekdays: Set<Weekday>
    /// The one date of a dated series. `nil` for a repeating series.
    public let date: LocalDate?
    public let members: [Member]
    /// Changes when a member joins, leaves, or gets another schedule version. A tap on a delivered
    /// reminder compares it with the plan of now, to see that the reminder is from an older plan (spec 8.3).
    public let revision: String
    /// The items, in the order of the schedules.
    let entries: [Entry]
    /// `false` when the user hides the names (D029).
    let showsNames: Bool
    /// The instant of the time on the date of a dated series. `nil` for a repeating series.
    let fireDate: Date?
    /// The members of a dated series that a record closed before its time. The request names only the others (D047).
    let done: Set<ScheduleSlotID>

    init(
        timeZone: NamedTimeZone?,
        time: WallClockTime,
        weekdays: Set<Weekday>,
        date: LocalDate? = nil,
        fireDate: Date? = nil,
        members: [Member],
        entries: [Entry] = [],
        showsNames: Bool = true,
        done: Set<ScheduleSlotID> = []
    ) {
        self.id = Self.identifierPrefix + (timeZone?.identifier ?? "device")
            + String(format: "|%02d:%02d", time.hour, time.minute)
        self.timeZone = timeZone
        self.time = time
        self.weekdays = weekdays
        self.date = date
        self.fireDate = fireDate
        self.members = members
        self.entries = entries
        self.showsNames = showsNames
        self.done = done
        // FNV-1a over the members in a fixed order. It only tells two member lists apart. It protects nothing.
        let text = members.map { "\($0.slotID.rawValue)=\($0.scheduleVersionID.rawValue)" }.sorted().joined(separator: ";")
        let hash = text.utf8.reduce(0xcbf2_9ce4_8422_2325 as UInt64) { ($0 ^ UInt64($1)) &* 0x100_0000_01b3 }
        self.revision = String(hash, radix: 16)
    }

    /// One daily request when the series reminds on every day with the same text. Otherwise one request
    /// for each weekday, because a request has one fixed text, and a day must not name an item that it does not have.
    ///
    /// A dated series has one request for its date. It names each of its open items once, and it has the
    /// "Taken" action when it has exactly one open item (D034, D047).
    public var requests: [ReminderRequest] {
        if let date {
            var seen = Set<ItemID>()
            let open = zip(members, entries).filter { !done.contains($0.0.slotID) }
            let named = open.map(\.1).filter { seen.insert($0.itemID).inserted }
            guard !open.isEmpty else { return [] }
            var userInfo = [
                ReminderRequest.seriesIDKey: id,
                ReminderRequest.scheduleRevisionKey: revision,
                ReminderRequest.dueDateKey: date.dayText,
            ]
            userInfo[ReminderRequest.ownerChangedKey] = ReminderRequest.ownerChangedText(of: named.map(\.ownerChangedAt))
            if !done.isEmpty {
                userInfo[ReminderRequest.openSlotsKey] = open.map { $0.0.slotID.rawValue.uuidString }.sorted().joined(separator: ",")
            }
            return [
                ReminderRequest(
                    identifier: id + "|" + date.dayText,
                    trigger: ReminderTrigger(time: time, weekday: nil, date: date, timeZone: timeZone),
                    content: Self.content(of: named, showsNames: showsNames),
                    userInfo: userInfo,
                    fireDate: fireDate
                ),
            ]
        }
        var contents = Dictionary(uniqueKeysWithValues: weekdays.map { ($0, content(on: $0)) })
        // With the names hidden, the text is the same on each day, and the series keeps its one daily request (D029).
        // That request has the action only when each of its days has exactly one item (D034).
        if !showsNames, Set(contents.values).count > 1 {
            contents = contents.mapValues { _ in ReminderContent(kind: .due, names: nil) }
        }
        let daily = weekdays.count == Weekday.allCases.count && Set(contents.values).count == 1
        let days: [Weekday?] = daily ? [nil] : weekdays.sorted()
        return days.map { weekday in
            var userInfo = [ReminderRequest.seriesIDKey: id, ReminderRequest.scheduleRevisionKey: revision]
            userInfo[ReminderRequest.ownerChangedKey] = ReminderRequest.ownerChangedText(
                of: entries.filter { weekday.map($0.weekdays.contains) ?? true }.map(\.ownerChangedAt)
            )
            return ReminderRequest(
                identifier: id + "|" + (weekday.map { String($0.rawValue) } ?? "daily"),
                trigger: ReminderTrigger(time: time, weekday: weekday, date: nil, timeZone: timeZone),
                content: weekday.map { contents[$0]! } ?? contents[.monday]!,
                userInfo: userInfo,
                fireDate: nil
            )
        }
    }

    /// The content of the series on one weekday: each item that reminds on that day, once.
    /// A day with exactly one item has the "Taken" action (D034).
    private func content(on weekday: Weekday) -> ReminderContent {
        var seen = Set<ItemID>()
        let named = entries.filter { $0.weekdays.contains(weekday) && seen.insert($0.itemID).inserted }
        return Self.content(of: named, showsNames: showsNames)
    }

    /// The text and the actions of a request that names these items, once each (D034, D123). The member count comes
    /// from the full list, never from a shortened text.
    private static func content(of named: [Entry], showsNames: Bool) -> ReminderContent {
        ReminderContent(
            kind: .due, names: showsNames ? named.map(\.reminderName) : nil,
            category: .choose(
                named: named.count, showsNames: showsNames, singleItem: named.count == 1,
                membersCount: Set(named.map(\.personID)).count
            )
        )
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
    /// The plan has more series requests than `ReminderPlan.requestBudget`.
    case overLimit
    /// The schedule, or its item, did not load from the database. The run skips it and keeps the pending requests that it may
    /// have, so a bad row never removes a reminder (D088).
    case unreadable
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
    /// The requests that the series can use, repeating and dated together. The follow-ups use the room
    /// that the series requests of the plan do not need, minus `FollowUpPlan.reserve` (spec 8.4, D039).
    public static let requestBudget = 48
    /// A plan with a day cycle gets dated requests for at least this many due dates at each of its times,
    /// from the date of the run (D036, D065). Each run sets them again. So its reminders stop after the last of
    /// these dates when the app does not run before it. A repeating request has no such limit.
    /// When the budget has room, the plan reaches further (D089, `horizons`).
    public static let datedDueDates = 7
    /// A weekday that a record before the dose time took out of the repeating request gets dated requests for at least this
    /// many weeks, the day of the record included (D047, D089).
    public static let reworkWeeks = 2
    /// The longer reach that the plan uses when the series requests still fit in `extendedBudget`, the longest first (D089).
    /// A choice must keep every series that the minimum keeps. The follow-ups use the room that is left.
    static let horizons: [(dueDates: Int, weeks: Int)] = [(28, 8), (21, 6), (14, 4), (10, 3)]
    /// The series requests that a longer reach may use. The rest of the room stays for the follow-ups (spec 8.4).
    static let extendedBudget = 32

    /// What one schedule needs from the system.
    public enum Need: Hashable, Sendable {
        /// The reminders are off, or the item is archived (T07, T08).
        case nothing
        /// The identifiers of the requests that remind for the schedule.
        case requests(Set<String>)
        /// An alarm rings for the schedule, so the series has no request for it (D079).
        /// The follow-ups still come for it, as notifications.
        case alarm
        /// The engine registers no complete reminder for the schedule.
        case blocked(ReminderProblem)
    }

    /// The series that the system gets, in the order of the schedules.
    public let series: [ReminderSeries]
    /// Every schedule of the plan. An item with no schedule is a list-only item and has no entry (T02).
    public let needs: [ScheduleID: Need]
    /// For each schedule that has dated requests: the instant of its last dated request. After it, a dose has no reminder
    /// until the app runs again (D089). A schedule with only repeating requests has no entry.
    public let coverageEnds: [ScheduleID: Date]
    /// The schedules that did not load (D088). Each has the need `.blocked(.unreadable)`. A run with such a schedule removes no
    /// request and no alarm, because the plan does not know what the schedule wants.
    public let unreadable: Set<ScheduleID>

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
    /// The repeating series get their requests first, in the order in which the schedules first use them.
    /// Then the dated series get theirs, in the same order. So a change of one plan to a day cycle
    /// never takes the repeating reminder of another plan.
    ///
    /// A version with a day cycle gets dated series: one for each of its next `datedDueDates`
    /// due dates at each of its times, when the instant of that time is after `now`. A day of the pause
    /// of a cycle is not a due date, so it gets no request. The dated series of one
    /// time and one time zone rule fit in the budget together, or none of them gets a request. So a schedule
    /// never has a reminder on some of its dates only.
    ///
    /// - Parameters:
    ///   - schedules: In a stable order, for example the order of the first save.
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the date of the versions that follow it.
    ///   - privacy: Whether the text names the items (D029).
    ///   - closed: The keys of the occurrences that have a current taken or skipped event (D047).
    ///   - longerReach: `false` keeps the minimum reach of `datedDueDates` and `reworkWeeks`. A test uses it.
    ///   - alarms: Which items an alarm covers now (D079). An item with `alarm` that an alarm covers gets no series
    ///     request, because its dose time rings. Any other item gets its normal reminder, so a revoked permission or
    ///     an alarm that the system did not schedule loses no reminder.
    ///   - family: The members, so the text names the owner of a dose when the Family has two or more active members (D123).
    public init(
        items: [Item],
        schedules: [Schedule],
        now: Date,
        deviceTimeZone: NamedTimeZone,
        privacy: ReminderPrivacy = .showNames,
        closed: Set<OccurrenceKey> = [],
        alarms: AlarmCover = .none,
        requestBudget: Int = ReminderPlan.requestBudget,
        longerReach: Bool = true,
        unreadable: Set<ScheduleID> = [],
        family: Family = Family()
    ) {
        struct Key: Hashable {
            let timeZone: NamedTimeZone?
            let time: WallClockTime
            /// The key of the dated series of a time. They are not the repeating series of that time.
            var isDated = false
        }
        /// One series: the repeating series of a key, or the dated series of a key on one date.
        struct Unit: Hashable {
            let key: Key
            var date: LocalDate?
        }
        /// `nil` means the time zone of the device.
        func seriesTimeZone(of version: ScheduleVersion) -> NamedTimeZone? {
            switch version.timeZonePolicy {
            case let .fixed(zone): zone
            case .followsDevice: nil
            }
        }
        /// The version that is in force at `now`, by the rule of `Schedule.version(on:)`.
        func inForce(_ schedule: Schedule) -> ScheduleVersion? {
            schedule.versions.last { $0.effectiveFrom <= LocalDate(now, in: seriesTimeZone(of: $0) ?? deviceTimeZone) }
        }
        // A named zone that equals the device zone now joins the series of the device when a version that follows
        // the device has the same time. So one time gives one request. The reminder of that item then follows
        // the device to another zone. The owner dropped the time zone question (D046, D047).
        let deviceTimes = Set(
            schedules.filter { $0.isEnabled && $0.endDate == nil }.compactMap(inForce).flatMap { version in
                version.timeZonePolicy == .followsDevice ? version.slotTimes.map(\.time) : []
            }
        )
        func keyTimeZone(of version: ScheduleVersion, at time: WallClockTime) -> NamedTimeZone? {
            if case let .fixed(zone) = version.timeZonePolicy, zone == deviceTimeZone, deviceTimes.contains(time) { return nil }
            return seriesTimeZone(of: version)
        }
        let activeItems = Dictionary(
            items.filter { !$0.isArchived }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        )
        var keys: [Key] = []
        var units: [Key: [Unit]] = [:]
        var weekdays: [Unit: Set<Weekday>] = [:]
        var members: [Unit: [ReminderSeries.Member]] = [:]
        var entries: [Unit: [ReminderSeries.Entry]] = [:]
        var fireDates: [Unit: Date] = [:]
        /// The place of a dated unit among the due dates of its slot. A shorter reach keeps the first ones.
        var ordinal: [Unit: Int] = [:]
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
            guard let version = inForce(schedule) else {
                needs[schedule.id] = .blocked(.notStarted)
                continue
            }
            if alarms.covers(item) {
                needs[schedule.id] = .alarm
                continue
            }
            for slotTime in version.slotTimes {
                let timeZone = keyTimeZone(of: version, at: slotTime.time)
                let key = Key(timeZone: timeZone, time: slotTime.time, isDated: version.dayCycle != nil)
                if units[key] == nil {
                    keys.append(key)
                    units[key] = []
                }
                keysOfSchedule[schedule.id, default: []].append(key)
                var slotUnits = [Unit(key: key)]
                if let cycle = version.dayCycle {
                    // The next due dates, from today in the zone of the plan. Only the time of today can be over.
                    let zone = timeZone ?? deviceTimeZone
                    var date = max(LocalDate(now, in: zone), cycle.start)
                    slotUnits = []
                    while slotUnits.count < Self.horizons[0].dueDates {
                        // A local time that a clock change removes or repeats uses its first instant (T25).
                        let instant = zone.resolve(slotTime.time, on: date).earliestInstant
                        if cycle.isDue(on: date), instant > now {
                            let unit = Unit(key: key, date: date)
                            fireDates[unit] = instant
                            ordinal[unit] = min(ordinal[unit] ?? slotUnits.count, slotUnits.count)
                            slotUnits.append(unit)
                        }
                        date = date.adding(days: 1)
                    }
                }
                for unit in slotUnits {
                    if members[unit] == nil { units[key]!.append(unit) }
                    if unit.date == nil { weekdays[unit, default: []].formUnion(version.weeklyRule.weekdays) }
                    members[unit, default: []].append(.init(slotID: slotTime.slotID, scheduleVersionID: version.id))
                    entries[unit, default: []].append(
                        .init(
                            itemID: item.id, name: item.name, personID: item.personID, ownerChangedAt: item.ownerChangedAt,
                            owner: family.owner(of: item),
                            weekdays: version.weeklyRule.weekdays
                        )
                    )
                }
            }
        }
        /// The series that fit for one reach (D089): the due dates of a plan with a day cycle, and the weeks of a weekday that
        /// a record or a day-cycle item changed.
        struct Layout {
            var kept: [Key: [ReminderSeries]] = [:]
            var shared: [Key: [ReminderSeries]] = [:]
            var used = 0
        }
        func layout(dueDates: Int, weeks: Int) -> Layout {
            var layout = Layout()
            for key in keys.filter({ !$0.isDated }) + keys.filter(\.isDated) {
                // The dated series of a key are in the order of their dates.
                let ordered = units[key]!.filter { $0.date == nil || ordinal[$0]! < dueDates }.sorted { first, second in
                    if let first = first.date, let second = second.date { first < second } else { false }
                }
                let series = ordered.map { unit -> ReminderSeries in
                    // A dated request names only the members that no record closed. With none left, it has no request.
                    // The budget counts it in full, so a record or an undo never changes which groups fit (D047).
                    let done = Set(members[unit]!.map(\.slotID)).filter { slot in
                        unit.date.map { closed.contains(OccurrenceKey(slotID: slot, plannedDate: $0)) } ?? false
                    }
                    return ReminderSeries(
                        timeZone: key.timeZone,
                        time: key.time,
                        weekdays: weekdays[unit] ?? [],
                        date: unit.date,
                        fireDate: fireDates[unit],
                        members: members[unit]!,
                        entries: entries[unit] ?? [],
                        showsNames: privacy == .showNames,
                        done: done
                    )
                }
                let count = series.baselineCount
                guard layout.used + count <= requestBudget else { continue }
                layout.used += count
                layout.kept[key] = series
            }
            /// The requests of one repeating series, with the weekdays on which a record or an item with a day cycle
            /// changes who is named. The next `weeks` dates of such a weekday get dated requests, and the weekday leaves
            /// the repeating requests, because a repeating request cannot skip one date. Each run sets them again,
            /// so a weekday with no run for `weeks` weeks reminds that many times and then stops (D047, D089).
            /// `nil` when no weekday needs this.
            func rework(_ key: Key, dated: [ReminderSeries]) -> [ReminderSeries]? {
                typealias Pair = (member: ReminderSeries.Member, entry: ReminderSeries.Entry)
                let own = Unit(key: key)
                let zone = key.timeZone ?? deviceTimeZone
                let today = LocalDate(now, in: zone)
                let repeating = Array(zip(members[own] ?? [], entries[own] ?? []).map { Pair($0.0, $0.1) })
                let datedUnits = units[Key(timeZone: key.timeZone, time: key.time, isDated: true)] ?? []
                let datedDates = Set(dated.compactMap(\.date))
                func due(on date: LocalDate) -> [Pair] {
                    let more = datedUnits.first { $0.date == date && datedDates.contains(date) }
                        .map { unit in Array(zip(members[unit]!, entries[unit]!).map { Pair($0.0, $0.1) }) } ?? []
                    return repeating.filter { $0.entry.weekdays.contains(date.weekday) } + more
                }
                func isOpen(_ pair: Pair, on date: LocalDate) -> Bool {
                    !closed.contains(OccurrenceKey(slotID: pair.member.slotID, plannedDate: date))
                }
                func instant(_ date: LocalDate) -> Date { zone.resolve(key.time, on: date).earliestInstant }
                /// The first `weeks` dates of a weekday from today that have not passed, and every date of a
                /// day-cycle request on that weekday. A dated request stays until a new one covers its members.
                func dates(of weekday: Weekday) -> [LocalDate] {
                    let first = (0..<7).map { today.adding(days: $0) }.first { $0.weekday == weekday }!
                    let own = (0..<weeks).map { first.adding(days: 7 * $0) } + datedDates.filter { $0.weekday == weekday }
                    return Set(own).filter { instant($0) > now }.sorted()
                }
                let all = weekdays[own] ?? []
                let changed = all.filter { weekday in
                    let expected = Set(repeating.filter { $0.entry.weekdays.contains(weekday) }.map(\.member.slotID))
                    return !dates(of: weekday).allSatisfy { date in
                        Set(due(on: date).filter { isOpen($0, on: date) }.map(\.member.slotID)) == expected
                    }
                }
                guard !changed.isEmpty else { return nil }
                let names = privacy == .showNames
                var result = [
                    ReminderSeries(
                        timeZone: key.timeZone, time: key.time, weekdays: all.subtracting(changed),
                        members: repeating.map(\.member), entries: repeating.map(\.entry), showsNames: names
                    ),
                ]
                for date in changed.flatMap(dates(of:)).sorted() {
                    let pairs = due(on: date)
                    let done = Set(pairs.filter { !isOpen($0, on: date) }.map(\.member.slotID))
                    guard done.count < pairs.count else { continue }
                    result.append(
                        ReminderSeries(
                            timeZone: key.timeZone, time: key.time, weekdays: [], date: date, fireDate: instant(date),
                            members: pairs.map(\.member), entries: pairs.map(\.entry), showsNames: names, done: done
                        )
                    )
                }
                // A day-cycle date on a weekday that the repeating series does not use stays as it is.
                return result + dated.filter { $0.date.map { !all.contains($0.weekday) } ?? false }
            }
            // A time with a record before it, or with a daily item and an item with a day cycle, gets the requests of
            // `rework` when they fit in the room that is left. The others keep their plain requests (D047).
            for key in keys where !key.isDated {
                let dated = Key(timeZone: key.timeZone, time: key.time, isDated: true)
                let before = (layout.kept[key] ?? []) + (layout.kept[dated] ?? [])
                guard layout.kept[key] != nil, let reworked = rework(key, dated: layout.kept[dated] ?? []),
                      layout.used - before.baselineCount + reworked.requestCount <= requestBudget
                else { continue }
                layout.used += reworked.requestCount - before.baselineCount
                layout.kept[key] = reworked
                if layout.kept[dated] != nil { layout.kept[dated] = [] }
                layout.shared[key] = reworked
                layout.shared[dated] = reworked
            }
            return layout
        }
        // The minimum reach is the rule of D036 and D047. A longer reach is used only when it keeps every series that the
        // minimum keeps and the series still fit in `extendedBudget`, so the follow-ups keep their room (D089).
        let minimum = layout(dueDates: Self.datedDueDates, weeks: Self.reworkWeeks)
        var chosen = minimum
        for horizon in longerReach ? Self.horizons : [] {
            let longer = layout(dueDates: horizon.dueDates, weeks: horizon.weeks)
            if longer.used <= Self.extendedBudget, Set(longer.kept.keys) == Set(minimum.kept.keys),
               Set(longer.shared.keys) == Set(minimum.shared.keys) {
                chosen = longer
                break
            }
        }
        var coverageEnds: [ScheduleID: Date] = [:]
        for schedule in schedules {
            guard let keys = keysOfSchedule[schedule.id] else { continue }
            let slots = Set(schedule.slots.map(\.id))
            let ends = keys.compactMap { key -> Date? in
                (chosen.shared[key] ?? chosen.kept[key] ?? []).filter { series in
                    !series.requests.isEmpty && series.members.contains { slots.contains($0.slotID) }
                }.compactMap { $0.date == nil ? nil : $0.fireDate }.max()
            }
            if let end = ends.min() { coverageEnds[schedule.id] = end }
        }
        for (scheduleID, keys) in keysOfSchedule {
            let series = keys.compactMap { chosen.shared[$0] ?? chosen.kept[$0] }
            needs[scheduleID] = series.count == keys.count
                ? .requests(Set(series.joined().flatMap(\.requests).map(\.identifier)))
                : .blocked(.overLimit)
        }
        for id in unreadable { needs[id] = .blocked(.unreadable) }
        self.unreadable = unreadable
        self.series = keys.flatMap { chosen.kept[$0] ?? [] }
        self.needs = needs
        self.coverageEnds = coverageEnds
    }
}

private extension Array where Element == ReminderSeries {
    var requestCount: Int { reduce(0) { $0 + $1.requests.count } }
    /// The requests that the series have when no record closes a dose (D047).
    var baselineCount: Int { reduce(0) { $0 + ($1.date == nil ? $1.requests.count : 1) } }
}
