import Foundation
import MaruCore
import UserNotifications

extension SystemReminderCenter: FollowUpCenter {
    public func add(_ request: FollowUpRequest) async throws {
        let request = UNNotificationRequest(request)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                continuation.resume(with: error.map(Result.failure) ?? .success(()))
            }
        }
    }

    public func delivered() async -> [PendingReminder] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications.map { PendingReminder($0.request) })
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
        let content = UNMutableNotificationContent()
        let text = request.content.text(locale: locale)
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.userInfo = request.userInfo
        // The follow-ups of one slot time show as one group in Notification Center (D039).
        content.threadIdentifier = request.threadIdentifier
        if request.content.hasTakenAction { content.categoryIdentifier = ReminderAction.categoryIdentifier }
        self.init(
            identifier: request.identifier,
            content: content,
            // The interval must be positive. The plan has only future instants, so this changes a few milliseconds at most.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, request.fireDate.timeIntervalSinceNow), repeats: false)
        )
    }
}

/// The follow-up setting in `UserDefaults.standard`. No interval means off (spec 4).
///
/// The interval key is the key of the one delay of D021. A value from before D039 has no count,
/// so it means one follow-up after that time. The earlier settings are JSON. They hold no health data (D014).
public struct DefaultsFollowUpSetting: FollowUpSettingStore {
    static let key = "reminders.followUpMinutes"
    static let countKey = "reminders.followUpCount"
    static let earlierKey = "reminders.followUpEarlier"

    public init() {}

    public func load() -> FollowUpSetting? {
        let defaults = UserDefaults.standard
        guard let interval = FollowUpInterval(rawValue: defaults.integer(forKey: Self.key)) else { return nil }
        let count = (defaults.object(forKey: Self.countKey) as? Int).flatMap(FollowUpCount.init)
        return FollowUpSetting(count: count ?? .one, interval: interval)
    }

    public func earlier() -> [FollowUpPeriod] {
        UserDefaults.standard.data(forKey: Self.earlierKey)
            .flatMap { try? JSONDecoder().decode([FollowUpPeriod].self, from: $0) } ?? []
    }

    public func save(_ setting: FollowUpSetting?) {
        let defaults = UserDefaults.standard
        let old = load()
        if old != setting {
            let now = Date()
            let kept = earlier().filter { $0.end > now.addingTimeInterval(-FollowUpPlan.periodsKept) }
            if let data = try? JSONEncoder().encode(kept + [FollowUpPeriod(setting: old, end: now)]) {
                defaults.set(data, forKey: Self.earlierKey)
            }
        }
        if let setting {
            defaults.set(setting.interval.rawValue, forKey: Self.key)
            defaults.set(setting.count.rawValue, forKey: Self.countKey)
        } else {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: Self.countKey)
        }
    }
}
