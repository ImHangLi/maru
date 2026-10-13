public enum ScheduleError: Error, Equatable, Sendable {
    case noSlotTimes
    case duplicateSlot(ScheduleSlotID)
    case unknownSlot(ScheduleSlotID)
    case foreignVersion
    case versionBeforeLatest
    case conflictingVersion(ScheduleVersionID)
    case noVersion
    /// A version with a day cycle has no weekday rule other than every day.
    case weekdaysWithDayCycle
    /// A number of days of a day cycle is outside `DayCycle.dayCounts`.
    case invalidDayCycle
}

/// A repeat rule that counts calendar days from a start date (D036, D065): `daysOn` days with a dose,
/// then `daysOff` days with none, and again. 1 and 1 give every other day. 1 and 2 give every third day.
/// 21 and 7 give three weeks with a dose and one week of pause.
public struct DayCycle: Hashable, Sendable {
    public let start: LocalDate
    public let daysOn: Int
    public let daysOff: Int

    /// The numbers of days that a cycle can have, and that the repeat page offers. Stored data with another
    /// number does not load, so a sum of the two numbers never overflows, and a search for the next due date
    /// is short.
    public static let dayCounts = 1...99

    public init(start: LocalDate, daysOn: Int, daysOff: Int) throws {
        guard Self.dayCounts.contains(daysOn), Self.dayCounts.contains(daysOff) else { throw ScheduleError.invalidDayCycle }
        self.start = start
        self.daysOn = daysOn
        self.daysOff = daysOff
    }

    /// The start date is due. The rule counts calendar dates and not hours, and it reads no record.
    public func isDue(on date: LocalDate) -> Bool {
        date >= start && date.days(since: start) % (daysOn + daysOff) < daysOn
    }

    /// The two cycles give the same due dates from `date` on. A cycle has no dose before its start date,
    /// so two cycles in the same rhythm differ only on the due dates of the earlier one before the later start.
    /// One full cycle from the earlier start always has a dose, so the check reads at most that many days.
    public func hasSameDueDates(as other: DayCycle, from date: LocalDate) -> Bool {
        let length = daysOn + daysOff
        guard (daysOn, daysOff) == (other.daysOn, other.daysOff), start.days(since: other.start).isMultiple(of: length) else {
            return false
        }
        let (earlier, later) = start < other.start ? (self, other) : (other, self)
        let first = max(date, earlier.start)
        return (0..<min(max(0, later.start.days(since: first)), length))
            .allSatisfy { !earlier.isDue(on: first.adding(days: $0)) }
    }
}

/// A stable identity for one daily dose point, such as "the morning one".
/// Changing its time never creates a new slot. Only the user adding another time point does.
public struct ScheduleSlot: Hashable, Sendable {
    public let id: ScheduleSlotID

    public init(id: ScheduleSlotID = ScheduleSlotID()) {
        self.id = id
    }
}

public struct SlotTime: Hashable, Sendable {
    public let slotID: ScheduleSlotID
    public var time: WallClockTime

    public init(slotID: ScheduleSlotID, time: WallClockTime) {
        self.slotID = slotID
        self.time = time
    }
}

/// An immutable set of reminder rules. An edit appends a new version and does not rewrite an old one.
public struct ScheduleVersion: Hashable, Sendable {
    public let id: ScheduleVersionID
    public let scheduleID: ScheduleID
    /// The version applies from this date until the next version takes over.
    public let effectiveFrom: LocalDate
    public let weeklyRule: WeeklyRule
    /// The day cycle of a version that repeats by a count of days (D036, D065). `nil` means that `weeklyRule` decides.
    /// Its start date can be before or after `effectiveFrom`: an edit of the time keeps it, so the rhythm stays.
    public let dayCycle: DayCycle?
    public let slotTimes: [SlotTime]
    /// The dose per intake as the user typed it. `nil` means no dose. There is no default dose.
    public let dose: Dose?
    public let timeZonePolicy: TimeZonePolicy

    public init(
        id: ScheduleVersionID = ScheduleVersionID(),
        scheduleID: ScheduleID,
        effectiveFrom: LocalDate,
        weeklyRule: WeeklyRule,
        dayCycle: DayCycle? = nil,
        slotTimes: [SlotTime],
        dose: Dose? = nil,
        timeZonePolicy: TimeZonePolicy
    ) throws {
        guard !slotTimes.isEmpty else { throw ScheduleError.noSlotTimes }
        guard dayCycle == nil || weeklyRule == .everyDay else { throw ScheduleError.weekdaysWithDayCycle }
        var seen = Set<ScheduleSlotID>()
        for slotTime in slotTimes where !seen.insert(slotTime.slotID).inserted {
            throw ScheduleError.duplicateSlot(slotTime.slotID)
        }
        self.id = id
        self.scheduleID = scheduleID
        self.effectiveFrom = effectiveFrom
        self.weeklyRule = weeklyRule
        self.dayCycle = dayCycle
        self.slotTimes = slotTimes
        self.dose = dose
        self.timeZonePolicy = timeZonePolicy
    }

    public func time(for slotID: ScheduleSlotID) -> WallClockTime? {
        slotTimes.first { $0.slotID == slotID }?.time
    }

    /// Whether the repeat rule has a dose on a date (spec 8.5, D036, D065).
    ///
    /// A version with a day cycle is due on the days of the cycle that have a dose, from its start date.
    /// The rule counts calendar dates of the plan, and not hours. So a clock change or another time zone
    /// does not move the rhythm, and a missed or skipped dose does not move it.
    public func isDue(on date: LocalDate) -> Bool {
        dayCycle?.isDue(on: date) ?? weeklyRule.weekdays.contains(date.weekday)
    }
}

/// The reminder plan of one item. `endDate == nil` means no end date, which is the default (spec 1).
/// An item with no `Schedule` is a list-only item (T02).
public struct Schedule: Hashable, Sendable {
    public let id: ScheduleID
    public let itemID: ItemID
    public var isEnabled: Bool
    public var endDate: LocalDate?
    /// Every slot that this schedule ever had. Old versions and old occurrences refer to them.
    public private(set) var slots: [ScheduleSlot] = []
    /// In append order. Effective dates never go backwards.
    public private(set) var versions: [ScheduleVersion] = []

    public init(id: ScheduleID = ScheduleID(), itemID: ItemID, isEnabled: Bool, endDate: LocalDate? = nil) {
        self.id = id
        self.itemID = itemID
        self.isEnabled = isEnabled
        self.endDate = endDate
    }

    /// Adds a new, independent time point. Call it only when the user adds another time of day.
    /// A slot ID can exist only once in a schedule.
    @discardableResult
    public mutating func addSlot(id: ScheduleSlotID = ScheduleSlotID()) throws -> ScheduleSlot {
        guard !slots.contains(where: { $0.id == id }) else { throw ScheduleError.duplicateSlot(id) }
        let slot = ScheduleSlot(id: id)
        slots.append(slot)
        return slot
    }

    /// Appends a version. Every slot in it must already belong to this schedule.
    /// Sending the same version again changes nothing. A different version with the same ID is rejected.
    public mutating func appendVersion(_ version: ScheduleVersion) throws {
        guard version.scheduleID == id else { throw ScheduleError.foreignVersion }
        if let existing = versions.first(where: { $0.id == version.id }) {
            guard existing == version else { throw ScheduleError.conflictingVersion(version.id) }
            return
        }
        let known = Set(slots.map(\.id))
        for slotTime in version.slotTimes where !known.contains(slotTime.slotID) {
            throw ScheduleError.unknownSlot(slotTime.slotID)
        }
        if let latest = versions.last, version.effectiveFrom < latest.effectiveFrom {
            throw ScheduleError.versionBeforeLatest
        }
        versions.append(version)
    }

    /// The version in force on a date. When two versions share a date, the later one wins.
    public func version(on date: LocalDate) -> ScheduleVersion? {
        versions.last { $0.effectiveFrom <= date }
    }

    /// Moves one slot to another time. The slot ID stays the same, so the edit never creates a new dose point.
    @discardableResult
    public mutating func changeTime(
        of slotID: ScheduleSlotID,
        to time: WallClockTime,
        effectiveFrom: LocalDate
    ) throws -> ScheduleVersion {
        guard let latest = versions.last else { throw ScheduleError.noVersion }
        guard latest.time(for: slotID) != nil else { throw ScheduleError.unknownSlot(slotID) }
        let slotTimes = latest.slotTimes.map { $0.slotID == slotID ? SlotTime(slotID: slotID, time: time) : $0 }
        let next = try ScheduleVersion(
            scheduleID: id,
            effectiveFrom: effectiveFrom,
            weeklyRule: latest.weeklyRule,
            dayCycle: latest.dayCycle,
            slotTimes: slotTimes,
            dose: latest.dose,
            timeZonePolicy: latest.timeZonePolicy
        )
        try appendVersion(next)
        return next
    }
}
