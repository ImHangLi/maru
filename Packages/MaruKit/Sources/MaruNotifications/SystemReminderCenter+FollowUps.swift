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
        if request.content.hasTakenAction { content.categoryIdentifier = ReminderAction.categoryIdentifier }
        self.init(
            identifier: request.identifier,
            content: content,
            // The interval must be positive. The plan has only future instants, so this changes a few milliseconds at most.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, request.fireDate.timeIntervalSinceNow), repeats: false)
        )
    }
}

/// The follow-up setting in `UserDefaults.standard`. No value means off (spec 4).
public struct DefaultsFollowUpSetting: FollowUpSettingStore {
    static let key = "reminders.followUpMinutes"

    public init() {}

    public func load() -> FollowUpDelay? {
        FollowUpDelay(rawValue: UserDefaults.standard.integer(forKey: Self.key))
    }

    public func save(_ delay: FollowUpDelay?) {
        if let delay {
            UserDefaults.standard.set(delay.rawValue, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}
