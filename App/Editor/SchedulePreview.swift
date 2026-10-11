import Foundation
import MaruCore

/// The text under the reminder times that states the whole plan, for example "Every day at 08:00, 20:00, with no end date" (spec 2.1, T03).
enum SchedulePreview {
    /// - Parameters:
    ///   - otherZone: The zone that a medication keeps, only when it is not the zone of the device (spec 8.5).
    ///   - today: Today in the zone of the plan. A plan of every second day that starts today or tomorrow says so.
    static func text(for draft: ItemDraft, problem: DraftProblem?, otherZone: NamedTimeZone?, today: LocalDate?) -> String {
        switch problem {
        case .noName:
            // Save stays off until the name has text. The line still shows the plan (D026).
            break
        case .noWeekday:
            return String(localized: "Choose at least one day.", comment: "Edit screen: the preview line when no weekday is on.")
        case .noFirstDay:
            return chooseFirstDay
        case .duplicateTime:
            return String(localized: "Two times are the same.", comment: "Edit screen: the preview line when two reminder times are equal.")
        case .noTimeZone:
            return String(
                localized: "Maru can’t use your time zone for reminders.",
                comment: "Edit screen: the preview line when the device time zone is an offset and not a city."
            )
        case let .laterVersion(date):
            let day = utcCalendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day))!
                .formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, calendar: utcCalendar, timeZone: .gmt))
            return String(
                localized: "You can change this plan again from \(day).",
                comment: "Edit screen: the preview line when the stored plan starts after today, for example after a flight west. The placeholder is a date."
            )
        case nil:
            break
        }
        guard !draft.times.isEmpty else {
            return String(
                localized: "No reminder",
                comment: "Edit screen: the preview line for an item with no time. Maru sends no notification for it."
            )
        }
        // With no name, the line still shows the plan, and a plan of every second day needs its first day.
        let start = draft.everyOtherDay?.start?.date
        if draft.everyOtherDay != nil, start == nil { return chooseFirstDay }
        var times = draft.sortedTimes.map { format(hour: $0.hour, minute: $0.minute) }
            .formatted(.list(type: .and, width: .narrow))
        if let otherZone {
            let local = draft.sortedTimes.map { localTime(hour: $0.hour, minute: $0.minute, in: otherZone) }
            // A time can fall on another day here, for example 9:00 am Monday in Shanghai is Sunday evening in
            // Los Angeles. Then each local time names its own days. Every day has no shift to show.
            let showsDays = draft.everyOtherDay == nil && draft.weekdays.count < Weekday.allCases.count
                && local.contains { $0.dayShift != 0 }
            let here = local.map { time in
                guard showsDays else { return time.text }
                let days = days(Set(draft.weekdays.map { $0.shifted(by: time.dayShift) }))
                return String(
                    localized: "\(days) \(time.text)",
                    comment: "Edit screen: a reminder time on the device with its days, when the kept zone of a medication is on another day. Example: Sun 6:00 PM."
                )
            }
            .formatted(.list(type: .and, width: .narrow))
            times = String(
                localized: "\(times) \(city(otherZone)) time (\(here) here for now)",
                comment: "Edit screen: the times of a medication in its kept zone. Example: 9:00 AM Shanghai time (6:00 PM here for now). \"For now\" because a clock change in either zone can move the local time or day later."
            )
        }
        let plan: String
        if let start, let today, start == today {
            plan = String(
                localized: "Every other day at \(times), starting today, with no end date",
                comment: "Edit screen: the preview line of a plan that repeats every second day from today. The placeholder is the times."
            )
        } else if let start, let today, start == today.adding(days: 1) {
            plan = String(
                localized: "Every other day at \(times), starting tomorrow, with no end date",
                comment: "Edit screen: the preview line of a plan that repeats every second day from tomorrow. The placeholder is the times."
            )
        } else {
            // A plan of every second day that started before today has no first day to name.
            let days = days(draft.weekdays, everyOtherDay: start != nil)
            plan = String(
                localized: "\(days) at \(times), with no end date",
                comment: "Edit screen: the preview line. The first placeholder is the days, for example Every day. The second is the times."
            )
        }
        guard let dose = Dose(draft.amount) else { return plan }
        // The amount has its own line.
        return "\(dose.text.trimmingCharacters(in: .whitespaces))\n\(plan)"
    }

    /// A time of day in the format of the user, for example 08:00 or 8:00 AM.
    static func format(hour: Int, minute: Int) -> String {
        timeDate(hour: hour, minute: minute).formatted(timeStyle)
    }

    /// The city of a zone, for example Shanghai for Asia/Shanghai.
    static func city(_ zone: NamedTimeZone) -> String {
        (zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier)
            .replacingOccurrences(of: "_", with: " ")
    }

    /// A time of today in a zone, shown in the time of the device. `dayShift` is -1 when the device is still
    /// on the day before, and 1 when it is on the day after.
    private static func localTime(hour: Int, minute: Int, in zone: NamedTimeZone) -> (text: String, dayShift: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone.identifier) ?? .gmt
        var parts = calendar.dateComponents([.year, .month, .day], from: .now)
        parts.hour = hour
        parts.minute = minute
        guard let date = calendar.date(from: parts) else { return (format(hour: hour, minute: minute), 0) }
        // Both sides use the Gregorian calendar, because the day shift compares their dates (a Buddhist or other
        // device calendar would give other year numbers).
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = .current
        let here = deviceCalendar.dateComponents([.year, .month, .day], from: date)
        let shift = utcCalendar.date(from: parts.withoutTime).flatMap { zoneDay in
            utcCalendar.date(from: here).flatMap { utcCalendar.dateComponents([.day], from: zoneDay, to: $0).day }
        } ?? 0
        return (date.formatted(date: .omitted, time: .shortened), shift)
    }

    /// A time of day has no date and no zone, so it uses a fixed day in UTC, as the reminder text does.
    static func timeDate(hour: Int, minute: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute))!
    }

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private static var timeStyle: Date.FormatStyle {
        Date.FormatStyle(date: .omitted, time: .shortened, calendar: utcCalendar, timeZone: .gmt)
    }

    private static var chooseFirstDay: String {
        String(
            localized: "Choose the first day.",
            comment: "Edit screen: the preview line and the hint when a plan repeats every second day and has no first day yet."
        )
    }

    /// The repeat rule of a plan in words: "Every other day", "Every day", or its weekdays (D036).
    static func days(_ weekdays: Set<Weekday>, everyOtherDay: Bool) -> String {
        guard everyOtherDay else { return days(weekdays) }
        return String(localized: "Every other day", comment: "The days of a plan that repeats every second day.")
    }

    static func days(_ weekdays: Set<Weekday>) -> String {
        if weekdays.count == Weekday.allCases.count {
            return String(localized: "Every day", comment: "Edit screen: the days of a plan that reminds on all seven days.")
        }
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return orderedWeekdays.filter(weekdays.contains)
            .map { symbols[$0.rawValue % 7] }
            .formatted(.list(type: .and, width: .narrow))
    }

    /// The seven days in the order of the user's calendar, for example from Sunday or from Monday.
    static var orderedWeekdays: [Weekday] {
        // `Calendar.firstWeekday` counts from Sunday = 1. `Weekday` counts from Monday = 1.
        let first = (Calendar.current.firstWeekday + 5) % 7 + 1
        return (0..<7).map { Weekday(rawValue: (first - 1 + $0) % 7 + 1)! }
    }
}

private extension DateComponents {
    var withoutTime: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }
}

private extension Weekday {
    /// The same weekday moved by a number of days, for example Monday by -1 is Sunday.
    func shifted(by days: Int) -> Weekday {
        Weekday(rawValue: ((rawValue - 1 + days) % 7 + 7) % 7 + 1)!
    }
}
