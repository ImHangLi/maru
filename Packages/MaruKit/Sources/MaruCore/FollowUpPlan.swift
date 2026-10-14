import Foundation

/// How many follow-ups one slot time gets while it has an open item (D039).
public enum FollowUpCount: Int, CaseIterable, Hashable, Sendable, Codable {
    case one = 1
    case two = 2
    case three = 3
    case five = 5
    /// "Until Recorded". The system has no request that repeats from a later time until the app stops it,
    /// and the app does not run in the background. So this is `untilRecordedLimit` dated requests, and
    /// the settings text states the number.
    case untilRecorded = 0

    /// The most follow-ups of one slot time with "Until Recorded". Four slot times of one day get this
    /// number each in the system limit: 4 × 12 follow-ups, 4 series requests, and the reserve are 54 of 64.
    public static let untilRecordedLimit = 12

    /// The most follow-ups of one slot time.
    public var limit: Int {
        self == .untilRecorded ? Self.untilRecordedLimit : rawValue
    }
}

/// The time from the slot time to the first follow-up, and from each follow-up to the next (D021, D039).
/// One minute is not a choice: it reads as an alarm that does not stop, and it fills the system limit at once.
public enum FollowUpInterval: Int, CaseIterable, Hashable, Sendable, Codable {
    case minutes5 = 5
    case minutes10 = 10
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60
}

/// The follow-up setting when it is on. The setting is off by default (spec 4), and "off" is `nil`.
public struct FollowUpSetting: Hashable, Sendable, Codable {
    public var count: FollowUpCount
    public var interval: FollowUpInterval

    public init(count: FollowUpCount, interval: FollowUpInterval) {
        self.count = count
        self.interval = interval
    }
}

/// One slot time on one date in one time zone: every occurrence of one series rule that fires at the same instant.
///
/// A follow-up belongs to such a group and not to one occurrence, as a series reminder does. So two items
/// at 08:00 give the same follow-ups, and each one comes while one of them is still open.
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
    ///
    /// It is the thread of every follow-up of the group, and the start of each request identifier.
    public var identifier: String {
        FollowUpRequest.identifierPrefix + (seriesTimeZone == nil ? "device@" : "") + timeZone.identifier
            + "|" + dateText + String(format: "|%02d:%02d", time.hour, time.minute)
    }

    /// The identifier of the follow-up at `instant`: the group identifier and `|+<minutes>` after the slot time.
    /// Items with other intervals can share a group, so the delay and not a count names a request (D079).
    func identifier(at instant: Date, from slotInstant: Date) -> String {
        identifier + "|+\(Int((instant.timeIntervalSince(slotInstant) / 60).rounded()))"
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
    /// The fire instant in ISO 8601 UTC. A new interval or a new device time zone changes it,
    /// so the engine then replaces the pending request.
    public static let fireTimeKey = "fireTime"
    /// The ID of the one item of a request with the "Taken" action. The action records only a dose of this item (D034).
    public static let itemIDKey = "itemID"
    /// The ID of the schedule version of the one dose of a request with the "Taken" action.
    /// The action records only a dose with this version (D034).
    public static let scheduleVersionIDKey = "scheduleVersionID"

    public let identifier: String
    /// The identifier of the group. The system shows the follow-ups of one slot time as one group (D039).
    public let threadIdentifier: String
    /// The items of the group that are open when the request is set, and that the request still reminds for (D029).
    /// Each record refreshes the follow-ups, so a recorded item leaves the text, and a closed group loses its requests.
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

/// The follow-ups that the saved plan, the records, and the setting ask for (D021, D039).
///
/// A slot time with an open item gets up to `FollowUpCount.limit` follow-ups. The first comes one interval
/// after the slot time, and each next one comes one interval after the one before. A follow-up reminds
/// for an item only before `latestTime` of the day after the dose, and before the next slot time of that item.
/// So a dose late in the evening also gets follow-ups. Until `latestTime`, the "Taken" action of such
/// a follow-up records the dose of the day before (D034, D039).
///
/// A dose never gets more than `FollowUpCount.untilRecordedLimit` follow-ups, also across a change of the setting.
/// A dose before the last change gets only the rest of that limit after the worst case of the follow-ups
/// that came before the change. So it can get fewer follow-ups than the setting says, never more than the limit.
///
/// It is a value of its inputs and reads no system state.
public struct FollowUpPlan: Hashable, Sendable {
    /// Follow-ups come for the slot times of the next seven days. The app sets them again at each run,
    /// so they stop when the app does not run for seven days. The series reminders continue.
    public static let days = 7
    /// The requests of the system limit that the follow-ups never use. One lets the series engine add a new
    /// request before it removes the old one (spec 8.4). One is spare: it was for the test notification of
    /// settings, which D076 removed.
    public static let reserve = 2
    /// The follow-ups of a dose stop at this time of the next day at the latest (D039).
    /// One hour after midnight: a dose late in the evening gets follow-ups, and a dose at bedtime
    /// does not get them all night.
    public static let latestTime = try! WallClockTime(hour: 1, minute: 0)

    /// The requests that the plan wants and that have room, nearest first. See `share`.
    public let requests: [FollowUpRequest]
    /// The text of each follow-up of each group that still has an open occurrence, by request identifier.
    /// A delivered follow-up with another identifier, or with another text, is removed.
    public let open: [String: ReminderContent]
    /// An item with a follow-up setting has a change that the engine did not confirm yet (`Date.distantFuture`).
    /// Old follow-ups can still come, so such an item gets none until the engine confirms their removal (D039, D079).
    public let hasUnconfirmedChange: Bool

    /// One open item of a dose group that a series reminder names (D084).
    private struct SeriesDose: Hashable, Sendable {
        let zoneText: String
        let timeZone: NamedTimeZone?
        let timeText: String
        let dateText: String
        let itemID: ItemID
        let name: String
        /// The position of the schedule. The series text lists the items in this order.
        let order: Int
    }

    /// The open items that a series reminder names, for each dose group. A delivered series notification is
    /// compared with this, and not with the series request that the plan wants now (D084).
    private let seriesDoses: [SeriesDose]
    private let deviceTimeZone: NamedTimeZone
    private let now: Date
    private let showsNames: Bool

    /// - Parameters:
    ///   - reminders: The series plan of the same read. A follow-up comes only for a schedule whose
    ///     series reminder is set up, so a paused, archived, ended, or blocked schedule gets none.
    ///     The follow-ups get only the room that the series requests of this plan do not need.
    ///   - items: Every item. An item with no `followUp` gets none (D079).
    ///   - stored: The stored occurrences on `OccurrenceGeneration.candidateDates`.
    ///   - closed: The keys of the occurrences that have a current taken or skipped event.
    ///   - now: The clock of the run.
    ///   - deviceTimeZone: The time zone of the device, for the schedule versions that follow it.
    ///   - privacy: Whether the text names the open items (D029).
    public init(
        reminders: ReminderPlan,
        items: [Item],
        schedules: [Schedule],
        stored: [StoredOccurrence],
        closed: Set<OccurrenceKey>,
        now: Date,
        deviceTimeZone: NamedTimeZone,
        privacy: ReminderPrivacy = .showNames
    ) {
        let reminding = schedules.filter {
            switch reminders.needs[$0.id] {
            case .requests?, .alarm?: true
            default: false
            }
        }
        let groups = DoseGroups(
            reminding: reminding, items: items, stored: stored, closed: closed, now: now, deviceTimeZone: deviceTimeZone
        )
        let itemOfID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // The items whose series request the plan sets. An item that an alarm covers has none (D079).
        let seriesItems = Set(schedules.compactMap { schedule -> ItemID? in
            if case .requests? = reminders.needs[schedule.id] { schedule.itemID } else { nil }
        })
        seriesDoses = groups.slotInstants.keys.sorted { $0.identifier < $1.identifier }.flatMap { group in
            groups.orderedOpenItems(of: group).filter { seriesItems.contains($0.itemID) }.compactMap { open in
                open.name.map {
                    SeriesDose(
                        zoneText: group.seriesTimeZone?.identifier ?? "device", timeZone: group.seriesTimeZone,
                        timeText: String(format: "%02d:%02d", group.time.hour, group.time.minute),
                        dateText: group.dateText, itemID: open.itemID, name: $0, order: open.order
                    )
                }
            }
        }
        self.deviceTimeZone = deviceTimeZone
        self.now = now
        showsNames = privacy == .showNames
        let end = now.addingTimeInterval(Double(Self.days) * 86_400)
        var contents: [String: ReminderContent] = [:]
        /// The requests of each group that are still to come, in the order of their instants.
        var wanted: [[FollowUpRequest]] = []
        for (group, slotInstant) in groups.slotInstants {
            let latest = Self.latestInstant(of: group.plannedDate, in: group.timeZone)
            // The open items with follow-ups, in the order of the schedules, each once, with the instant at which
            // their follow-ups stop: `latestTime` of the next day, or the next slot time of the item, the first of the two.
            let reminded = groups.orderedOpenItems(of: group).compactMap { open -> (
                name: String, setting: FollowUpSetting, changed: Date?, stop: Date
            )? in
                guard let item = itemOfID[open.itemID], let setting = item.followUp else { return nil }
                let next = groups.doses[open.itemID]!.filter { $0 > slotInstant }.min()
                return (item.name, setting, item.followUpChanged, min(latest, next ?? latest))
            }
            guard !reminded.isEmpty else { continue }
            let single = groups.single(of: group)
            /// The names of the items that each instant reminds for. `shown` has every instant that an item reaches,
            /// and `due` only the instants that still get a request.
            var shown: [Date: [String]] = [:]
            var due: [Date: [String]] = [:]
            for item in reminded {
                let step = Double(item.setting.interval.rawValue * 60)
                // A dose before the last change can have follow-ups of earlier settings. Each interval is a multiple of
                // 5 minutes, so at most one came for each 5 minutes from the slot time to `changed`. The setting of now
                // gets only the rest of the limit, and only after `changed`. A later dose gets the setting of now.
                let came = item.changed.map {
                    min(FollowUpCount.untilRecordedLimit, max(0, Int($0.timeIntervalSince(slotInstant) / 300)))
                } ?? 0
                let left = min(item.setting.count.limit, FollowUpCount.untilRecordedLimit - came)
                var counted = 0
                for number in 1... {
                    guard counted < left || number <= item.setting.count.limit else { break }
                    let fireDate = slotInstant.addingTimeInterval(Double(number) * step)
                    // The instants only grow, so a later follow-up has no time left too.
                    guard item.stop > fireDate else { break }
                    // A delivered follow-up of an earlier setting can have this instant. It stays while its text is true.
                    shown[fireDate, default: []].append(item.name)
                    guard counted < left, fireDate > item.changed ?? .distantPast else { continue }
                    counted += 1
                    guard fireDate > now, fireDate <= end else { continue }
                    due[fireDate, default: []].append(item.name)
                }
            }
            func content(_ names: [String]) -> ReminderContent {
                // `nil` when the user hides the names.
                let shownNames = privacy == .showNames ? names : []
                return ReminderContent(kind: .again, names: shownNames.isEmpty ? nil : shownNames, hasTakenAction: single != nil)
            }
            for (fireDate, names) in shown {
                contents[group.identifier(at: fireDate, from: slotInstant)] = content(names)
            }
            var future: [FollowUpRequest] = []
            for fireDate in due.keys.sorted() {
                var userInfo = [
                    ReminderRequest.seriesIDKey: group.seriesID,
                    FollowUpRequest.plannedDateKey: group.dateText,
                    FollowUpRequest.fireTimeKey: fireDate.formatted(.iso8601),
                ]
                // The action records only the dose that the request was made for, also after a plan change (D034).
                if let single {
                    userInfo[FollowUpRequest.itemIDKey] = single.itemID.rawValue.uuidString
                    userInfo[FollowUpRequest.scheduleVersionIDKey] = single.versionID.rawValue.uuidString
                }
                future.append(
                    FollowUpRequest(
                        identifier: group.identifier(at: fireDate, from: slotInstant), threadIdentifier: group.identifier,
                        content: content(due[fireDate]!), userInfo: userInfo, fireDate: fireDate
                    )
                )
            }
            if !future.isEmpty { wanted.append(future) }
        }
        open = contents
        hasUnconfirmedChange = items.contains { $0.followUp != nil && $0.followUpChanged == .distantFuture }
        requests = Self.share(
            wanted, room: ReminderPlan.systemLimit - Self.reserve - reminders.requests.count, from: now
        )
    }

    /// What a delivered series notification may say now: the items of its time and date that are active and have
    /// no record (D084). `nil` when no such item is left, so the notification must go. The notification system shows the
    /// text that the app set before. It does not follow a record, an archive, or a delete.
    ///
    /// - Parameters:
    ///   - identifier: The identifier of the notification, as `ReminderSeries` makes it.
    ///   - deliveredAt: When the system delivered it. A repeating request has no date, so the date of the delivery gives it.
    public func deliveredSeriesContent(identifier: String, deliveredAt: Date?) -> ReminderContent? {
        let parts = identifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] + "|" == ReminderSeries.identifierPrefix else { return nil }
        let zone = parts[1] == "device" ? deviceTimeZone : (try? NamedTimeZone(identifier: parts[1])) ?? deviceTimeZone
        let delivered = deliveredAt ?? now
        let date: LocalDate
        if let dated = LocalDate(dayText: parts[3]) {
            date = dated
        } else {
            // A repeating request has no date. The planned date is the latest date on the weekday of the request whose
            // planned instant is at or before the delivery, as `ReminderTapResolver` reads it. So a reminder of 23:59
            // that the system delivers at 00:01 belongs to the day before.
            let clock = parts[2].split(separator: ":").compactMap { Int($0) }
            let time = clock.count == 2 ? try? WallClockTime(hour: clock[0], minute: clock[1]) : nil
            let weekday = Int(parts[3]).flatMap(Weekday.init(rawValue:))
            let last = LocalDate(delivered, in: zone)
            date = time.flatMap { time in
                (0...ReminderTapResolver.delayedLookBack).map { last.adding(days: -$0) }.first { day in
                    (weekday.map { day.weekday == $0 } ?? true)
                        && zone.resolve(time, on: day).earliestInstant <= delivered.addingTimeInterval(ReminderTapResolver.earlyTolerance)
                }
            } ?? last
        }
        var seen = Set<ItemID>()
        // A named zone that equals the device zone can join the series of the device (D047). The items are in the order
        // of the schedules, as in the text of the series request, so the same set of items gives the same text.
        let names = seriesDoses.filter {
            $0.dateText == date.dayText && $0.timeText == parts[2]
                && ($0.zoneText == parts[1] || (parts[1] == "device" && $0.timeZone == deviceTimeZone))
        }.sorted { $0.order < $1.order }.filter { seen.insert($0.itemID).inserted }.map(\.name)
        guard !names.isEmpty else { return nil }
        return ReminderContent(kind: .due, names: showsNames ? names : nil)
    }

    /// The instant at which the follow-ups of a dose on `date` stop at the latest: `latestTime` of the next day.
    /// Until then, the "Taken" action of a follow-up records the dose (D034, D039).
    public static func latestInstant(of date: LocalDate, in zone: NamedTimeZone) -> Date {
        zone.resolve(latestTime, on: date.adding(days: 1)).earliestInstant
    }

    /// Whether the "Taken" action of a follow-up can record the dose on `date` at `now`: the date is today,
    /// or the day before until `latestTime` (D034, D039). Today shows only the doses of today (D019).
    public static func takesDose(on date: LocalDate, at now: Date, in zone: NamedTimeZone) -> Bool {
        let today = LocalDate(now, in: zone)
        return date == today || (date == today.adding(days: -1) && now < latestInstant(of: date, in: zone))
    }

    /// The requests that get room, nearest first (D039).
    ///
    /// The series requests come first: `room` is the system limit minus the reserve and every series request
    /// of the plan, so a follow-up never takes the room of a first reminder (spec 8.4).
    ///
    /// The groups whose next follow-up comes in the same 24 hours from `now` share the room. Each group gets
    /// its next follow-up in turn, the nearest group first, then each group gets one more, until every request
    /// of these groups has room or no room is left. So one slot time does not take the room of the others.
    /// Then the groups of the next 24 hours get the room that is left, in the same way.
    ///
    /// - Parameter groups: The requests of each group that are still to come, in the order of their instants.
    static func share(_ groups: [[FollowUpRequest]], room: Int, from now: Date) -> [FollowUpRequest] {
        var kept: [FollowUpRequest] = []
        let days = Dictionary(grouping: groups) { Int($0[0].fireDate.timeIntervalSince(now) / 86_400) }
        for day in days.keys.sorted() where kept.count < room {
            kept += days[day]!
                .flatMap { $0.enumerated().map { (turn: $0.offset, request: $0.element) } }
                .sorted {
                    ($0.turn, $0.request.fireDate, $0.request.identifier) < ($1.turn, $1.request.fireDate, $1.request.identifier)
                }
                .prefix(room - kept.count)
                .map(\.request)
        }
        return kept.sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
    }
}
