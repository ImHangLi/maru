import Foundation

// On `FormatStyle`, so `date.formatted(.rowTime(in: zone))` finds it (SE-0299).
extension FormatStyle where Self == Date.FormatStyle {
    /// The time of a dose in a row, for example "8:07 AM" or "08:07", as the region of the user writes it (spec 13.2).
    /// Today, the as-needed doses, the reminder choice, and History use it.
    static func rowTime(in timeZone: TimeZone) -> Self {
        Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
    }
}
