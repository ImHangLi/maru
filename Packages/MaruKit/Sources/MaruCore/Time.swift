import Foundation

public enum TimeError: Error, Equatable, Sendable {
    case invalidDate
    case invalidWallClockTime
    case emptyWeekdays
    case unknownTimeZone(String)
}

/// A calendar date with no time and no time zone, for example the logical plan date of an occurrence.
public struct LocalDate: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard DateComponents(calendar: calendar, year: year, month: month, day: day).isValidDate else {
            throw TimeError.invalidDate
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// A wall-clock time of day, for example 08:00. It is not an instant.
public struct WallClockTime: Hashable, Comparable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) throws {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else {
            throw TimeError.invalidWallClockTime
        }
        self.hour = hour
        self.minute = minute
    }

    public static func < (lhs: WallClockTime, rhs: WallClockTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

public enum Weekday: Int, CaseIterable, Hashable, Comparable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A weekly rule: the set of weekdays on which a slot fires. V1 has no every-X-hours rule (spec 8.5).
public struct WeeklyRule: Hashable, Sendable {
    public let weekdays: Set<Weekday>

    public init(weekdays: Set<Weekday>) throws {
        guard !weekdays.isEmpty else { throw TimeError.emptyWeekdays }
        self.weekdays = weekdays
    }

    public static let everyDay = WeeklyRule(validated: Set(Weekday.allCases))

    private init(validated weekdays: Set<Weekday>) {
        self.weekdays = weekdays
    }
}

/// An IANA region time zone name such as `Asia/Shanghai`, or the explicit `UTC`.
/// Offset-only strings such as `GMT+0800` and fixed-offset `Etc/` zones are rejected (spec 8.5).
public struct NamedTimeZone: Hashable, Sendable {
    public let identifier: String

    public static let utc = NamedTimeZone(validated: "UTC")

    public init(identifier: String) throws {
        let isRegion = identifier.contains("/")
            && !identifier.hasPrefix("Etc/")
            && TimeZone.knownTimeZoneIdentifiers.contains(identifier)
        guard identifier == "UTC" || isRegion else {
            throw TimeError.unknownTimeZone(identifier)
        }
        self.identifier = identifier
    }

    private init(validated identifier: String) {
        self.identifier = identifier
    }
}

/// How a schedule version treats time zones (spec 8.5).
public enum TimeZonePolicy: Hashable, Sendable {
    /// Keep the confirmed calendar semantics of one named zone. The default for medication.
    case fixed(NamedTimeZone)
    /// Follow the local life time of the device. Allowed for supplements.
    case followsDevice
}
