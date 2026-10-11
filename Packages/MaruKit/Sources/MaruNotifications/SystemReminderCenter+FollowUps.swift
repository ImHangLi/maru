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
/// The setting and the time of its last change live in one value under one key, so one write changes both.
/// A stop of the app can never leave a new setting with an old confirmed time (D039). The keys from before
/// this value are read only when the value is missing: the interval key of D021, with no count meaning one
/// follow-up, and the change key. The value holds no health data (D014).
public struct DefaultsFollowUpSetting: FollowUpSettingStore {
    static let valueKey = "reminders.followUp.v2"
    static let key = "reminders.followUpMinutes"
    static let countKey = "reminders.followUpCount"
    static let changedKey = "reminders.followUpChanged"
    /// The engine confirms and the settings screen saves from different tasks. The lock makes each read and write of the value one step.
    private static let lock = NSLock()

    public init() {}

    public func load() -> FollowUpSetting? {
        Self.lock.withLock { Self.read().setting }
    }

    public func changed() -> Date? {
        Self.lock.withLock { Self.read().changed }
    }

    public func save(_ setting: FollowUpSetting?) {
        Self.lock.withLock {
            let current = Self.read()
            guard current.setting != setting else { return }
            // "Off" also counts: the old follow-ups can still come until the engine confirms their removal.
            Self.write(setting: setting, changed: .distantFuture)
        }
    }

    public func confirmChange() -> Date {
        Self.lock.withLock {
            let now = Date()
            let current = Self.read()
            // A save after the engine read the mark wrote a new mark. That change stays unconfirmed for the next run.
            if current.changed == .distantFuture { Self.write(setting: current.setting, changed: now) }
            return now
        }
    }

    private static func read() -> (setting: FollowUpSetting?, changed: Date?) {
        let defaults = UserDefaults.standard
        if let value = defaults.dictionary(forKey: valueKey) {
            let interval = (value["minutes"] as? Int).flatMap(FollowUpInterval.init)
            let count = (value["count"] as? Int).flatMap(FollowUpCount.init)
            return (interval.map { FollowUpSetting(count: count ?? .one, interval: $0) }, value["changed"] as? Date)
        }
        let interval = FollowUpInterval(rawValue: defaults.integer(forKey: key))
        let count = (defaults.object(forKey: countKey) as? Int).flatMap(FollowUpCount.init)
        return (interval.map { FollowUpSetting(count: count ?? .one, interval: $0) }, defaults.object(forKey: changedKey) as? Date)
    }

    private static func write(setting: FollowUpSetting?, changed: Date) {
        var value: [String: Any] = ["changed": changed]
        if let setting {
            value["minutes"] = setting.interval.rawValue
            value["count"] = setting.count.rawValue
        }
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: valueKey)
        for old in [key, countKey, changedKey] { defaults.removeObject(forKey: old) }
    }
}
