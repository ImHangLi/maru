import Foundation

/// A delivered reminder that the user tapped, as the system gives it (spec 8.3).
public struct DeliveredReminder: Hashable, Sendable {
    /// The delivery date of the system (`UNNotification.date`). It is not the planned time, and it is not
    /// the time of an intake.
    public let deliveredAt: Date
    /// The `userInfo` of the request. A series request has `ReminderRequest.seriesIDKey` and
    /// `ReminderRequest.scheduleRevisionKey`. A dated request also has `ReminderRequest.dueDateKey` (D036).
    public let userInfo: [String: String]
    /// The weekday of the request trigger, or `nil` for a request that fires every day.
    /// A weekly request fires only on its weekday, so the planned date has this weekday.
    public let triggerWeekday: Weekday?

    public init(deliveredAt: Date, userInfo: [String: String], triggerWeekday: Weekday?) {
        self.deliveredAt = deliveredAt
        self.userInfo = userInfo
        self.triggerWeekday = triggerWeekday
    }
}

extension Weekday {
    /// The weekday of a calendar component, which counts from Sunday = 1, for example
    /// `UNCalendarNotificationTrigger.dateComponents.weekday`.
    public init?(calendarWeekday: Int) {
        guard (1...7).contains(calendarWeekday) else { return nil }
        self.init(rawValue: (calendarWeekday + 5) % 7 + 1)
    }
}

/// The device time zone that the reminder engine saw, and since when it sees that zone (spec 8.3).
public struct ObservedTimeZone: Hashable, Sendable {
    public let timeZone: NamedTimeZone
    /// The clock of the first successful run that saw this zone, after no run or after a run that saw another zone.
    public let since: Date

    public init(timeZone: NamedTimeZone, since: Date) {
        self.timeZone = timeZone
        self.since = since
    }
}

/// Why the app asks the user to confirm the date and the items of a tapped reminder (spec 8.3, T15, T24).
public enum ReminderTapDoubt: Hashable, Sendable {
    /// The planned date is not today. The tap must not record a new occurrence of today (T15).
    case otherDay
    /// The system delivered the reminder later than its planned time.
    /// The delay says nothing about when the user took the dose (T24).
    case delayed
    /// The series follows the device, and the app cannot show that the device had the zone of now at the delivery.
    /// The date of the delivery is then not certain.
    case zoneChange
    /// The reminder is from an older plan: its revision is not the revision of the plan for its date.
    case olderPlan
    /// A clock change removes or repeats the planned time on the date, so the planned instant is not one instant (T25).
    case clockChange
    /// No item of the plan matches the reminder on its date.
    case noMatch
}

/// What a tap on a delivered reminder opens.
public enum ReminderTapResolution: Hashable, Sendable {
    /// One date and one time are certain. The occurrences are every item of the plan at that time on that date.
    /// The app opens them for the user to record. It records nothing by itself (spec 8.3).
    case resolved([PlannedOccurrence])
    /// The app shows a confirmation screen. The user picks among the candidates, or opens Today.
    /// The candidates can be empty, for example when the plan no longer has the time.
    case confirm(candidates: [PlannedOccurrence], doubts: Set<ReminderTapDoubt>)
    /// The request is not a series reminder of this version of the app. Open Today.
    case notSeries
}

/// Finds the occurrences of a tapped series reminder (spec 8.3).
///
/// A repeating request fires on many dates, so it carries the series ID and the revision, and no occurrence ID.
/// The resolver reads the date from the delivery date, the trigger weekday, the trigger time and zone in the series ID,
/// the device zone that the engine saw, and the version history of the schedules. It is a value of its inputs and reads no system state.
///
/// The tap time (`now`) only tells whether the planned date is today. It is never a planned time or an intake time.
public struct ReminderTapResolver: Sendable {
    /// A delivery up to this long after the planned instant counts as on time.
    public static let onTimeTolerance: TimeInterval = 5 * 60
    /// A delivery up to this long before the planned instant counts as on time, for a small clock difference.
    static let earlyTolerance: TimeInterval = 60
    /// A delayed reminder offers this many dates: the last planned date before the delivery, and the ones before it.
    static let delayedDates = 2
    /// How far back the resolver looks for the planned dates of a delayed reminder. A weekly series fires at least once a week.
    static let delayedLookBack = 8
    /// The largest difference between the UTC offsets of two zones (UTC-12 to UTC+14). When the zone of the delivery
    /// is not known, the planned instant in the zone of now is at most this far from the delivery.
    static let zoneSpread: TimeInterval = 26 * 60 * 60

    public let now: Date
    public let deviceTimeZone: NamedTimeZone
    /// What `DefaultsTimeZoneRecord.load()` returns. `nil` when the engine did not complete a run.
    public let observedTimeZone: ObservedTimeZone?

    public init(now: Date, deviceTimeZone: NamedTimeZone, observedTimeZone: ObservedTimeZone?) {
        self.now = now
        self.deviceTimeZone = deviceTimeZone
        self.observedTimeZone = observedTimeZone
    }

    /// - Parameters:
    ///   - items: Every item, also the archived ones.
    ///   - schedules: Every schedule with its full version history.
    public func resolve(_ reminder: DeliveredReminder, items: [Item], schedules: [Schedule]) -> ReminderTapResolution {
        guard let seriesID = reminder.userInfo[ReminderRequest.seriesIDKey],
              let series = SeriesKey(seriesID: seriesID, deviceTimeZone: deviceTimeZone)
        else { return .notSeries }
        let revision = reminder.userInfo[ReminderRequest.scheduleRevisionKey]
        // A repeating request stands for the slots with a weekly rule. A follow-up stands for every slot of its time.
        let rule: SeriesKey.Rule? = reminder.userInfo[FollowUpRequest.plannedDateKey] == nil ? .weekly : nil
        // A series that follows the device fired in the zone that the device had then. That zone is the zone of now
        // only when the engine saw the zone of now before the delivery, and no other zone since.
        let zone = series.timeZone ?? deviceTimeZone
        let zoneIsKnown = series.timeZone != nil
            || observedTimeZone.map { $0.timeZone == deviceTimeZone && $0.since < reminder.deliveredAt } == true
        // A weekly request fires only on its weekday. A delivery near the time of another weekday is not that date.
        let onTriggerWeekday = { (date: LocalDate) in reminder.triggerWeekday.map { date.weekday == $0 } ?? true }
        let activeItems = Set(items.filter { !$0.isArchived }.map(\.id))
        let schedules = schedules.filter { activeItems.contains($0.itemID) }
        let deliveryDate = LocalDate(reminder.deliveredAt, in: zone)
        let today = LocalDate(now, in: zone)

        // A dated request carries its plan date, so the resolver does not read the date from the delivery (D036).
        // Its members are the slots with a day cycle that are due on that date.
        if let dueDate = reminder.userInfo[ReminderRequest.dueDateKey] {
            guard let date = LocalDate(dayText: dueDate) else { return .notSeries }
            let planned = zone.resolve(series.time, on: date)
            let lag = reminder.deliveredAt.timeIntervalSince(planned.earliestInstant)
            var doubts = Set<ReminderTapDoubt>()
            if date != today { doubts.insert(.otherDay) }
            if planned.needsReview { doubts.insert(.clockChange) }
            if !zoneIsKnown {
                doubts.insert(.zoneChange)
            } else if !(-Self.earlyTolerance...Self.onTimeTolerance).contains(lag) {
                doubts.insert(.delayed)
            }
            let reminding = schedules.filter { $0.isEnabled && $0.endDate == nil }
            // The dated request of an item with a day cycle stands for those items. A dated request that
            // replaces a repeating request, or that joins both kinds, stands for every item due on its date (D047).
            let matched = [SeriesKey.Rule.dayCycle, .dated].first {
                revision != nil && revision == series.revision(on: date, schedules: reminding, rule: $0)
            }
            let isCurrent = matched != nil
            if !isCurrent { doubts.insert(.olderPlan) }
            var candidates = series.candidates(
                on: date, schedules: isCurrent ? reminding : schedules, zone: zone, current: isCurrent,
                rule: matched ?? .dayCycle
            )
            // A record before the time closed some members. The request names and stands for the open ones only.
            if isCurrent, let open = reminder.userInfo[ReminderRequest.openSlotsKey] {
                let slots = Set(open.split(separator: ",").map(String.init))
                candidates = candidates.filter { slots.contains($0.slotID.rawValue.uuidString) }
            }
            if candidates.isEmpty { doubts.insert(.noMatch) }
            return doubts.isEmpty ? .resolved(candidates) : .confirm(candidates: candidates, doubts: doubts)
        }

        // On time: the delivery is at the planned instant of its date, or of the date before for a time near midnight.
        // A daily request delayed by almost exactly a day also looks on time. The user still sees the date and records.
        for date in [deliveryDate, deliveryDate.adding(days: -1)] where zoneIsKnown && onTriggerWeekday(date) {
            let planned = zone.resolve(series.time, on: date)
            let lag = reminder.deliveredAt.timeIntervalSince(planned.earliestInstant)
            guard (-Self.earlyTolerance...Self.onTimeTolerance).contains(lag) else { continue }
            var doubts = Set<ReminderTapDoubt>()
            if date != today { doubts.insert(.otherDay) }
            if planned.needsReview { doubts.insert(.clockChange) }
            // The plan registers only the schedules that remind. With the revision of that plan, the members are certain.
            let reminding = schedules.filter { $0.isEnabled && $0.endDate == nil }
            let isCurrent = revision != nil && revision == series.revision(on: date, schedules: reminding, rule: .weekly)
            if !isCurrent { doubts.insert(.olderPlan) }
            let candidates = series.candidates(
                on: date, schedules: isCurrent ? reminding : schedules, zone: zone, current: isCurrent, rule: rule
            )
            if candidates.isEmpty { doubts.insert(.noMatch) }
            return doubts.isEmpty ? .resolved(candidates) : .confirm(candidates: candidates, doubts: doubts)
        }

        // Delayed: offer the last planned dates before the delivery. The resolver does not choose one of them.
        // With the zone not known, offer every date that the delivery can have in some zone.
        let dates = (zoneIsKnown ? Array(0...Self.delayedLookBack) : Array(-2...2))
            .map { deliveryDate.adding(days: -$0) }
            .filter(onTriggerWeekday)
            .filter {
                let planned = zone.resolve(series.time, on: $0).earliestInstant
                return zoneIsKnown
                    ? planned <= reminder.deliveredAt
                    : abs(planned.timeIntervalSince(reminder.deliveredAt)) <= Self.zoneSpread
            }
            .filter { !series.candidates(on: $0, schedules: schedules, zone: zone, current: false, rule: rule).isEmpty }
            .prefix(zoneIsKnown ? Self.delayedDates : .max)
        let candidates = dates.flatMap {
            series.candidates(on: $0, schedules: schedules, zone: zone, current: false, rule: rule)
        }
        var doubts: Set<ReminderTapDoubt> = [zoneIsKnown ? .delayed : .zoneChange]
        if dates.contains(where: { $0 != today }) { doubts.insert(.otherDay) }
        if candidates.isEmpty { doubts.insert(.noMatch) }
        return .confirm(candidates: candidates, doubts: doubts)
    }
}

/// What the "Taken" action of a delivered reminder can record (spec 8.3, D034).
public enum ReminderActionTarget: Hashable, Sendable {
    /// The one open dose of the reminder, with its stored record. The new event revises the last event of the record.
    case open(Occurrence, OccurrenceRecord)
    /// The one dose of the reminder is already taken. The action has nothing to do.
    case alreadyTaken
    /// The reminder does not give exactly one open dose of today. The action records nothing.
    case none
}

/// The doses that an action of a delivered reminder stands for, before the stored state is checked (spec 8.3, D034, D090).
public struct ReminderActionDoses: Hashable, Sendable {
    /// How many doses the reminder names. The action counts the doses that fail a check against this number.
    public let named: Int
    /// The doses that the plan of now still has with the schedule version of the request. Each still needs the checks of the stored occurrence.
    public let doses: [PlannedOccurrence]

    public init(named: Int, doses: [PlannedOccurrence]) {
        self.named = named
        self.doses = doses
    }
}

extension ReminderTapResolver {
    /// The doses that "Taken", "Skip", "Take All", and "Skip All" of a delivered reminder stand for (spec 8.3, D034, D090).
    ///
    /// A series reminder must resolve with no doubt, by the rules of `resolve`: on time, today, the plan of now, and no clock change.
    /// Its revision names the slots and the schedule versions of its members, so a reminder from before a plan change does not
    /// resolve. All doses of its time and date are then the doses that it names. A dated request follows the same rules, with the date
    /// that it carries (D036).
    ///
    /// A follow-up or a snooze has no revision. It carries its plan date, and one of two identities:
    /// - The ID of its one item and of its schedule version (D034). The doses are those of that item: exactly one.
    /// - The list of its doses (`FollowUpRequest.membersKey`, D090). A dose stays only when the plan of now still has its slot with
    ///   the schedule version of the list. A dose that does not stay is a dose that fails, and the other doses stay.
    /// The date of a follow-up must be today, or the day before until `FollowUpPlan.latestTime`. The device zone must be certain for a
    /// series that follows the device. A request with no identity gives no dose.
    public func actionDoses(of reminder: DeliveredReminder, items: [Item], schedules: [Schedule]) -> ReminderActionDoses {
        guard reminder.userInfo[FollowUpRequest.plannedDateKey] != nil else {
            guard case let .resolved(found) = resolve(reminder, items: items, schedules: schedules) else {
                return ReminderActionDoses(named: 0, doses: [])
            }
            return ReminderActionDoses(named: found.count, doses: found)
        }
        guard let context = followUpContext(reminder, items: items, schedules: schedules) else {
            return ReminderActionDoses(named: reminder.userInfo[FollowUpRequest.membersKey]?.split(separator: ",").count ?? 1, doses: [])
        }
        if let text = reminder.userInfo[FollowUpRequest.membersKey] {
            let entries = text.split(separator: ",").map { $0.split(separator: "=").compactMap { UUID(uuidString: String($0)) } }
            let members = entries.compactMap { parts -> (slot: ScheduleSlotID, version: ScheduleVersionID)? in
                parts.count == 2 ? (ScheduleSlotID(parts[0]), ScheduleVersionID(parts[1])) : nil
            }
            guard members.count == entries.count else { return ReminderActionDoses(named: entries.count, doses: []) }
            let doses = context.candidates.filter { candidate in
                members.contains { $0.slot == candidate.slotID && $0.version == candidate.scheduleVersionID }
            }
            return ReminderActionDoses(named: members.count, doses: doses)
        }
        // A dose of another item at this time means that the plan changed. Then the action records nothing.
        let itemID = reminder.userInfo[FollowUpRequest.itemIDKey]
        let ownSlots = Set(context.reminding.filter { $0.itemID.rawValue.uuidString == itemID }.flatMap(\.slots).map(\.id))
        let own = itemID != nil && context.candidates.allSatisfy { ownSlots.contains($0.slotID) }
        return ReminderActionDoses(named: 1, doses: own && context.candidates.count == 1 ? context.candidates : [])
    }

    /// The one-time request of a "Remind in 10 min" action: the group of the reminder and the time at which it comes again (D090).
    /// `nil` when the reminder does not name a dose of today that the plan has, or when the new time is not before `latestTime` of
    /// the day after the dose: the follow-ups of that dose have stopped.
    public func snoozeEntry(of reminder: DeliveredReminder, items: [Item], schedules: [Schedule]) -> SnoozeEntry? {
        guard let seriesID = reminder.userInfo[ReminderRequest.seriesIDKey] else { return nil }
        let date: LocalDate
        let zone: NamedTimeZone
        if reminder.userInfo[FollowUpRequest.plannedDateKey] != nil {
            guard let context = followUpContext(reminder, items: items, schedules: schedules) else { return nil }
            (date, zone) = (context.date, context.zone)
        } else {
            guard case let .resolved(found) = resolve(reminder, items: items, schedules: schedules), let first = found.first else {
                return nil
            }
            (date, zone) = (first.plannedDate, first.timeZone)
        }
        let fireAt = now.addingTimeInterval(Double(SnoozeEntry.minutes) * 60)
        guard fireAt < FollowUpPlan.latestInstant(of: date, in: zone) else { return nil }
        return SnoozeEntry(seriesID: seriesID, plannedDate: date.dayText, fireAt: fireAt)
    }

    /// What a follow-up or a snooze names, when the action can still record a dose of its date (`FollowUpPlan.takesDose`):
    /// the doses that the plan of now has at its time and on its date, and the schedules that remind.
    private func followUpContext(
        _ reminder: DeliveredReminder, items: [Item], schedules: [Schedule]
    ) -> (date: LocalDate, zone: NamedTimeZone, candidates: [PlannedOccurrence], reminding: [Schedule])? {
        let dateParts = (reminder.userInfo[FollowUpRequest.plannedDateKey] ?? "").split(separator: "-").compactMap { Int($0) }
        guard let seriesID = reminder.userInfo[ReminderRequest.seriesIDKey],
              let series = SeriesKey(seriesID: seriesID, deviceTimeZone: deviceTimeZone),
              dateParts.count == 3,
              let date = try? LocalDate(year: dateParts[0], month: dateParts[1], day: dateParts[2])
        else { return nil }
        let zone = series.timeZone ?? deviceTimeZone
        let zoneIsKnown = series.timeZone != nil
            || observedTimeZone.map { $0.timeZone == deviceTimeZone && $0.since < reminder.deliveredAt } == true
        guard zoneIsKnown, FollowUpPlan.takesDose(on: date, at: now, in: zone) else { return nil }
        let activeItems = Set(items.filter { !$0.isArchived }.map(\.id))
        // A follow-up comes only for a schedule that reminds.
        let reminding = schedules.filter { activeItems.contains($0.itemID) && $0.isEnabled && $0.endDate == nil }
        let candidates = series.candidates(on: date, schedules: reminding, zone: zone, current: true, rule: nil)
        return (date, zone, candidates, reminding)
    }
}

/// The trigger of a series, read back from its ID (`ReminderSeries.id`).
private struct SeriesKey {
    /// `nil` means the time zone of the device.
    let timeZone: NamedTimeZone?
    let time: WallClockTime
    /// A series of the device also holds the versions with a named zone that equals this zone,
    /// as `ReminderPlan` joins them (D047).
    let deviceTimeZone: NamedTimeZone

    init?(seriesID: String, deviceTimeZone: NamedTimeZone) {
        self.deviceTimeZone = deviceTimeZone
        let parts = seriesID.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3, "\(parts[0])|" == ReminderSeries.identifierPrefix else { return nil }
        let clock = parts[2].split(separator: ":")
        guard clock.count == 2, let hour = Int(clock[0]), let minute = Int(clock[1]),
              let time = try? WallClockTime(hour: hour, minute: minute)
        else { return nil }
        if parts[1] == "device" {
            timeZone = nil
        } else {
            guard let zone = try? NamedTimeZone(identifier: String(parts[1])) else { return nil }
            timeZone = zone
        }
        self.time = time
    }

    /// The repeat rule of the versions that a request stands for. A repeating request and a dated request
    /// at the same time have different members (D036).
    enum Rule {
        case weekly
        case dayCycle
        /// Every version that is due on the date, with any repeat rule (D047).
        case dated
    }

    /// Whether a version reminds in the time zone rule of this series, with the repeat rule. `nil` means each rule.
    func matches(_ version: ScheduleVersion, rule: Rule?) -> Bool {
        let inZone = switch version.timeZonePolicy {
        case let .fixed(zone): zone == timeZone || (timeZone == nil && zone == deviceTimeZone)
        case .followsDevice: timeZone == nil
        }
        return switch rule {
        case nil, .dated: inZone
        case .weekly: inZone && version.dayCycle == nil
        case .dayCycle: inZone && version.dayCycle != nil
        }
    }

    /// The revision that `ReminderPlan` gives this series on a date, with the version in force on the date.
    /// Pass the schedules that remind. For a repeating series, the members of every weekday count, as in
    /// `ReminderSeries`. For a dated series, only the members that are due on the date count.
    func revision(on date: LocalDate, schedules: [Schedule], rule: Rule) -> String? {
        let members = schedules.flatMap { schedule in
            guard let version = schedule.version(on: date), matches(version, rule: rule),
                  rule == .weekly || version.isDue(on: date)
            else {
                return [ReminderSeries.Member]()
            }
            return version.slotTimes.filter { $0.time == time }.map {
                ReminderSeries.Member(slotID: $0.slotID, scheduleVersionID: version.id)
            }
        }
        guard !members.isEmpty else { return nil }
        return ReminderSeries(timeZone: timeZone, time: time, weekdays: [], members: members).revision
    }

    /// The occurrences that the plan of today has on the date for the slots of this series.
    ///
    /// With `current`, a slot belongs to the series when the version in force on the date has it at the series time.
    /// Without it, the slot can also have the time in the version of the day before, because the system can still
    /// hold a request of that version. The occurrence then has the time of the plan of today, as a stored
    /// occurrence with no intake follows the plan (D019).
    func candidates(
        on date: LocalDate, schedules: [Schedule], zone: NamedTimeZone, current: Bool, rule: Rule?
    ) -> [PlannedOccurrence] {
        schedules.flatMap { schedule in
            let versions = current ? [schedule.version(on: date)] : [schedule.version(on: date), schedule.version(on: date.adding(days: -1))]
            let slots = Set(versions.compactMap { $0 }.filter { matches($0, rule: rule) }.flatMap { version in
                version.slotTimes.filter { $0.time == time }.map(\.slotID)
            })
            return schedule.plannedOccurrences(on: date, deviceTimeZone: zone).filter { slots.contains($0.slotID) }
        }
    }
}
