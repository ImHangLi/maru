import Foundation
import MaruCore

/// When Maru asks for an App Store rating (D102). Only the system prompt of `RequestReviewAction` shows, and the
/// system decides if it appears.
///
/// Maru asks right after the record that completes a day, from the third distinct day on which every planned dose has a
/// record. It asks at most once per app version, and never in the first 3 days after the first launch. The values are
/// preferences in `UserDefaults.standard`, not in the health database (D014). They hold dates and a version, and no
/// item data.
enum ReviewPrompt {
    private static let firstLaunchKey = "review.firstLaunch"
    private static let completeDaysKey = "review.completeDays"
    private static let askedVersionKey = "review.askedVersion"
    /// The time of the last ask. The Maru Pro card does not show on that day (D107).
    private static let askedAtKey = "review.askedAt"
    private static let daysNeeded = 3
    private static let firstDays: TimeInterval = 3 * 24 * 60 * 60

    /// Keeps the time of the first launch. A launch before this rule existed is not known, so an update counts as the
    /// first launch.
    static func noteLaunch(defaults: UserDefaults = .standard, now: Date = Date()) {
        guard defaults.object(forKey: firstLaunchKey) == nil else { return }
        defaults.set(now, forKey: firstLaunchKey)
    }

    /// Counts a day on which every planned dose has a record. `true` when Maru asks now. `canAsk` is `false` while the
    /// user does not see the app. An ask is kept, so the same version does not ask again.
    static func dayDidComplete(
        _ day: LocalDate, canAsk: Bool, defaults: UserDefaults = .standard, now: Date = Date()
    ) -> Bool {
        var days = defaults.stringArray(forKey: completeDaysKey) ?? []
        let key = String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
        if days.count < daysNeeded, !days.contains(key) {
            days.append(key)
            defaults.set(days, forKey: completeDaysKey)
        }
        guard canAsk, days.count >= daysNeeded,
              let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date,
              now.timeIntervalSince(firstLaunch) >= firstDays,
              let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              defaults.string(forKey: askedVersionKey) != version
        else { return false }
        defaults.set(version, forKey: askedVersionKey)
        defaults.set(now, forKey: askedAtKey)
        return true
    }

    /// The time of the first launch that this rule knows. The Maru Pro card counts its days from it (D107).
    static func firstLaunch(defaults: UserDefaults = .standard) -> Date? {
        defaults.object(forKey: firstLaunchKey) as? Date
    }

    /// Maru asked for a rating on the calendar day of `now`.
    static func askedToday(defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        guard let askedAt = defaults.object(forKey: askedAtKey) as? Date else { return false }
        return Calendar.current.isDate(askedAt, inSameDayAs: now)
    }
}
