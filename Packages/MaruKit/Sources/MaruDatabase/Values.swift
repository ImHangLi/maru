import Foundation
import MaruCore

// How domain values are stored in columns. A stored value that does not decode is `StorageError.invalidData`.

extension Identifier {
    var text: String { rawValue.uuidString }

    init(text: String) throws(StorageError) {
        guard let uuid = UUID(uuidString: text) else { throw .invalidData }
        self.init(uuid)
    }
}

extension LocalDate {
    /// `YYYY-MM-DD`, so text order is date order.
    var text: String {
        get throws(StorageError) {
            guard (1...9999).contains(year) else { throw .invalidData }
            return String(format: "%04d-%02d-%02d", year, month, day)
        }
    }

    init(text: String) throws(StorageError) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3, let year = parts[0], let month = parts[1], let day = parts[2],
              let date = try? LocalDate(year: year, month: month, day: day)
        else { throw .invalidData }
        self = date
    }
}

extension WallClockTime {
    /// `HH:MM`.
    var text: String { String(format: "%02d:%02d", hour, minute) }

    init(text: String) throws(StorageError) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 2, let hour = parts[0], let minute = parts[1],
              let time = try? WallClockTime(hour: hour, minute: minute)
        else { throw .invalidData }
        self = time
    }
}

extension WeeklyRule {
    /// The weekday numbers in order, for example `135` for Monday, Wednesday, and Friday.
    var text: String { weekdays.sorted().map { String($0.rawValue) }.joined() }

    init(text: String) throws(StorageError) {
        let weekdays = text.compactMap { $0.wholeNumberValue.flatMap(Weekday.init(rawValue:)) }
        guard let rule = try? WeeklyRule(weekdays: Set(weekdays)), rule.text == text else { throw .invalidData }
        self = rule
    }
}

extension NamedTimeZone {
    init(text: String) throws(StorageError) {
        guard let zone = try? NamedTimeZone(identifier: text) else { throw .invalidData }
        self = zone
    }
}

extension Date {
    /// Seconds since 2001-01-01 UTC. This is the value that `Date` holds, so a stored instant loads unchanged.
    var storedSeconds: Double { timeIntervalSinceReferenceDate }

    init(storedSeconds: Double) {
        self.init(timeIntervalSinceReferenceDate: storedSeconds)
    }
}

extension RawRepresentable where RawValue == String {
    init(text: String) throws(StorageError) {
        guard let value = Self(rawValue: text) else { throw .invalidData }
        self = value
    }
}
