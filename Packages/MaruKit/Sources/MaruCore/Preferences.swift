public enum AppLanguage: String, CaseIterable, Hashable, Sendable {
    case system
    case en
    case zhHans
}

public enum ReminderPrivacy: String, CaseIterable, Hashable, Sendable {
    /// Notifications name no item.
    case hideNames
    /// Notifications show the item names. This is the default (D029).
    case showNames
}

public enum AnalyticsConsent: String, CaseIterable, Hashable, Sendable {
    /// The user has not decided. Treat it as no consent.
    case notAsked
    case granted
    case denied
}

/// App settings. They are kept apart from health data (spec 7.1).
public struct Preferences: Hashable, Sendable {
    public var language: AppLanguage
    public var reminderPrivacy: ReminderPrivacy
    public var analyticsConsent: AnalyticsConsent

    public init(language: AppLanguage, reminderPrivacy: ReminderPrivacy, analyticsConsent: AnalyticsConsent) {
        self.language = language
        self.reminderPrivacy = reminderPrivacy
        self.analyticsConsent = analyticsConsent
    }

    /// No analytics consent. Reminders name the items (D029). The user can turn the names off in settings.
    public static let `default` = Preferences(language: .system, reminderPrivacy: .showNames, analyticsConsent: .notAsked)
}
