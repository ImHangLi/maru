import Foundation

/// UTC has no clock changes, so every day in this calendar has 24 hours.
private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}()

/// The instant of a wall-clock time on a date in a named time zone (spec 8.5, T25).
///
/// A clock change can remove a local time or give it two times. The occurrence stays one occurrence
/// in both cases. It is flagged for review, and the app does not choose an instant for the user.
public enum ResolvedLocalTime: Hashable, Sendable {
    /// The local time comes one time on this date.
    case exact(Date)
    /// The clock moves forward over the local time, so it does not come on this date.
    /// `firstValidAfter` is the instant of the clock change, which is the first local time after the gap.
    case nonexistent(firstValidAfter: Date)
    /// The clock moves back over the local time, so it comes two times on this date.
    case repeated(first: Date, second: Date)

    /// The user must check the time. Show this state, and do not present one instant as the planned time.
    public var needsReview: Bool {
        switch self {
        case .exact: false
        case .nonexistent, .repeated: true
        }
    }

    /// The first instant that the local time can mean. Use it to put occurrences in order, not as the time of an intake.
    public var earliestInstant: Date {
        switch self {
        case let .exact(instant), let .nonexistent(instant), let .repeated(instant, _): instant
        }
    }
}

extension LocalDate {
    /// The calendar date of an instant in a time zone.
    public init(_ instant: Date, in timeZone: NamedTimeZone) {
        var calendar = utcCalendar
        calendar.timeZone = timeZone.systemZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        self.year = parts.year!
        self.month = parts.month!
        self.day = parts.day!
    }

    /// The date `days` after this one. A negative number gives an earlier date.
    public func adding(days: Int) -> LocalDate {
        LocalDate(instantInUTC().addingTimeInterval(Double(days) * 86_400), in: .utc)
    }

    public var weekday: Weekday {
        // The calendar counts from Sunday = 1. `Weekday` counts from Monday = 1.
        Weekday(rawValue: (utcCalendar.component(.weekday, from: instantInUTC()) + 5) % 7 + 1)!
    }

    /// The date, and a wall-clock time on it, read as UTC.
    fileprivate func instantInUTC(at time: WallClockTime? = nil) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: time?.hour, minute: time?.minute))!
    }
}

extension WallClockTime {
    /// The clock time of an instant in a time zone, to the minute.
    public init(_ instant: Date, in timeZone: NamedTimeZone) {
        var calendar = utcCalendar
        calendar.timeZone = timeZone.systemZone
        let parts = calendar.dateComponents([.hour, .minute], from: instant)
        self.hour = parts.hour!
        self.minute = parts.minute!
    }
}

extension NamedTimeZone {
    /// `init` accepts only an identifier that the system knows, so the zone exists.
    var systemZone: TimeZone { TimeZone(identifier: identifier)! }

    /// The instant of a wall-clock time on a date in this zone. The rules of the named zone decide,
    /// not one UTC offset, so the result follows each clock change of the zone (spec 8.5, T25).
    public func resolve(_ time: WallClockTime, on date: LocalDate) -> ResolvedLocalTime {
        let zone = systemZone
        // The local time read as UTC. The instant is this value minus the offset that the zone has at the instant.
        let unshifted = date.instantInUTC(at: time)
        // One day before and one day after are on the two sides of a clock change next to the local time.
        let offsets = Set([-86_400.0, 86_400.0].map { zone.secondsFromGMT(for: unshifted.addingTimeInterval($0)) })
        let instants = offsets.map { unshifted.addingTimeInterval(-Double($0)) }.sorted()
        // An instant is the local time only when the zone shows that local time at the instant.
        let valid = instants.filter { unshifted.addingTimeInterval(-Double(zone.secondsFromGMT(for: $0))) == $0 }
        switch valid.count {
        case 1:
            return .exact(valid[0])
        case 2:
            return .repeated(first: valid[0], second: valid[1])
        default:
            // The clock change is between the two instants. Find the first second with the new offset.
            var (low, high) = (instants[0], instants[instants.count - 1])
            let oldOffset = zone.secondsFromGMT(for: low)
            while high.timeIntervalSince(low) > 1 {
                let middle = low.addingTimeInterval((high.timeIntervalSince(low) / 2).rounded())
                if zone.secondsFromGMT(for: middle) == oldOffset { low = middle } else { high = middle }
            }
            return .nonexistent(firstValidAfter: high)
        }
    }
}
