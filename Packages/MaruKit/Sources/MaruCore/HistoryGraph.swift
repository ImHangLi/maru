import Foundation

/// The calendar of the graph on the history page (D041). One column is one week, and one row is one weekday,
/// from the first weekday of the user. Time runs from left to right.
///
/// The graph grows with use: 13 weeks, 26 weeks when 13 are full, then 52 weeks. The last column is always
/// the week of today, so the graph shows no future weeks (D092). Days before the first day have no record.
/// After 52 weeks it moves one column each week. Older days stay in the timeline.
public struct HistoryGraph: Hashable, Sendable {
    /// The scale steps in weeks. The graph takes the next step on the first day of a week that does not fit.
    public static let steps = [13, 26, 52]

    /// 13, 26, or 52.
    public let weeks: Int
    /// The first date of the first column.
    public let start: LocalDate
    /// The last date with a cell. A later date is not here yet.
    public let today: LocalDate
    /// The first date that can have a dose. An earlier date has no cell.
    public let firstDay: LocalDate

    public init(today: LocalDate, firstDay: LocalDate, firstWeekday: Weekday) {
        let thisWeek = Self.weekStart(of: today, firstWeekday: firstWeekday)
        // A plan can start after today. The graph then starts today.
        let firstDay = min(firstDay, today)
        let firstWeek = Self.weekStart(of: firstDay, firstWeekday: firstWeekday)
        let used = thisWeek.days(since: firstWeek) / 7 + 1
        let weeks = Self.steps.first { used <= $0 } ?? Self.steps[Self.steps.count - 1]
        self.weeks = weeks
        self.start = thisWeek.adding(days: -7 * (weeks - 1))
        self.today = today
        self.firstDay = firstDay
    }

    /// The first date of the oldest week that the graph can show. The read for the graph starts here.
    public static func oldestStart(today: LocalDate, firstWeekday: Weekday) -> LocalDate {
        weekStart(of: today, firstWeekday: firstWeekday).adding(days: -7 * (steps[steps.count - 1] - 1))
    }

    /// The first date of the week of `date`.
    public static func weekStart(of date: LocalDate, firstWeekday: Weekday) -> LocalDate {
        date.adding(days: -((date.weekday.rawValue - firstWeekday.rawValue + 7) % 7))
    }

    public func date(column: Int, row: Int) -> LocalDate {
        start.adding(days: column * 7 + row)
    }

    public func cell(of date: LocalDate) -> (column: Int, row: Int) {
        let offset = date.days(since: start)
        return (offset / 7, offset % 7)
    }

    /// A date from the first day to today has a cell that shows its record. A later date shows as not here yet.
    public func isShown(_ date: LocalDate) -> Bool {
        date >= max(firstDay, start) && date <= today
    }

    /// The month labels of some columns: each column where a month starts. When no month starts in the first
    /// three columns, the first column gets the month of its first date, so the graph always names a month.
    public func monthLabels(columns: Range<Int>) -> [(column: Int, month: LocalDate)] {
        var labels: [(column: Int, month: LocalDate)] = []
        for column in columns {
            if let first = (0..<7).map({ date(column: column, row: $0) }).first(where: { $0.day == 1 }) {
                labels.append((column, first))
            }
        }
        if let lower = columns.first, !labels.contains(where: { $0.column < lower + 3 }) {
            labels.insert((lower, date(column: lower, row: 0)), at: 0)
        }
        return labels
    }
}
