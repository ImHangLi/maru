import Foundation
import MaruCore

/// The setting "Show Names in Reminders" in `UserDefaults.standard`. No value means on (D029).
public struct DefaultsReminderPrivacy: ReminderPrivacyStore {
    static let key = "reminders.hideNames"

    public init() {}

    public func load() -> ReminderPrivacy {
        UserDefaults.standard.bool(forKey: Self.key) ? .hideNames : .showNames
    }

    public func save(_ privacy: ReminderPrivacy) {
        if privacy == .hideNames {
            UserDefaults.standard.set(true, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}
