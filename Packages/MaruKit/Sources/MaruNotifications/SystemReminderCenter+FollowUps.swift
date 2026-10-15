import Foundation
import MaruCore
import UserNotifications

extension SystemReminderCenter: FollowUpCenter {
    public func add(_ request: FollowUpRequest) async throws {
        try await Self.submit(UNNotificationRequest(request))
    }

    public func delivered() async -> [PendingReminder] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications.map { PendingReminder($0.request, deliveredAt: $0.date) })
            }
        }
    }

    public func removeDelivered(identifiers: [String]) async {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

extension UNNotificationRequest {
    /// A one-time interval request to the exact fire instant, measured from now (the time of the refresh).
    /// The text is fixed here, in the language of now (spec 8.2, D029).
    convenience init(_ request: FollowUpRequest, locale: Locale = .current) {
        self.init(
            identifier: request.identifier,
            // The follow-ups of one slot time show as one group in Notification Center (D039).
            content: UNMutableNotificationContent.reminder(
                request.content, userInfo: request.userInfo, threadIdentifier: request.threadIdentifier, locale: locale
            ),
            // The interval must be positive. The plan has only future instants, so this changes a few milliseconds at most.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, request.fireDate.timeIntervalSinceNow), repeats: false)
        )
    }
}

/// The global follow-up setting of version 1.0, in `UserDefaults.standard` (D079).
///
/// Version 1.1 keeps the setting of each item in the database. The app reads this value one time at launch,
/// copies it to every item, and removes it. The value is a dictionary with `minutes`, `count`, and `changed` under `reminders.followUp.v2`.
/// The keys from before that value are read only when the value is missing: the interval key of D021, with no
/// count meaning one follow-up. The value holds no health data (D014).
public enum LegacyFollowUpSetting {
    static let valueKey = "reminders.followUp.v2"
    static let key = "reminders.followUpMinutes"
    static let countKey = "reminders.followUpCount"
    static let changedKey = "reminders.followUpChanged"

    /// The setting that an install of version 1.0 had, or `nil` when it was off or never set.
    public static func read(in defaults: UserDefaults = .standard) -> FollowUpSetting? {
        let minutes: Int?
        let count: Int?
        if let value = defaults.dictionary(forKey: valueKey) {
            minutes = value["minutes"] as? Int
            count = value["count"] as? Int
        } else {
            minutes = defaults.integer(forKey: key) == 0 ? nil : defaults.integer(forKey: key)
            count = defaults.object(forKey: countKey) as? Int
        }
        guard let interval = minutes.flatMap(FollowUpInterval.init) else { return nil }
        // A missing count means "1 Time", as for an install from before D039.
        return FollowUpSetting(count: count.flatMap(FollowUpCount.init) ?? .one, interval: interval)
    }

    /// The time of the last change of the setting, for the limit of a dose (D039, D079). A change that the engine
    /// did not confirm has `Date.distantFuture`. Old follow-ups can still come until the system confirms their removal.
    /// The items keep this value, and the follow-up engine writes the time of the confirmation, as D039 does.
    public static func changeTime(in defaults: UserDefaults = .standard) -> Date? {
        (defaults.dictionary(forKey: valueKey)?["changed"] as? Date) ?? defaults.object(forKey: changedKey) as? Date
    }

    /// Whether a value of version 1.0 is still there, also one that means off.
    public static func exists(in defaults: UserDefaults = .standard) -> Bool {
        [valueKey, key, countKey, changedKey].contains { defaults.object(forKey: $0) != nil }
    }

    /// Removes every key of the setting.
    public static func remove(in defaults: UserDefaults = .standard) {
        for old in [valueKey, key, countKey, changedKey] { defaults.removeObject(forKey: old) }
    }
}
