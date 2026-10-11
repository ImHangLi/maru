public enum ReminderPrivacy: String, CaseIterable, Hashable, Sendable {
    /// Notifications name no item.
    case hideNames
    /// Notifications show the item names. This is the default (D029).
    case showNames
}
