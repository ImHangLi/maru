import Foundation

/// The way an analytics event leaves `MaruCore` (spec 11.4). The domain code holds no vendor SDK.
public protocol AnalyticsClient: Sendable {
    /// Queues one event. It never blocks, and it never throws.
    func capture(_ event: AnalyticsEvent)
    /// Queues one event that the caller keeps until the server confirms it (D144). `id` and `time` stay the same for a repeat
    /// send, so the server counts one event. `acknowledged` runs only after that confirmation.
    func capture(_ event: AnalyticsEvent, id: UUID, time: Date, acknowledged: @escaping @Sendable () -> Void)
    /// Sends the queued events now, and returns when the send ends (D144). A wait after a failed request still applies.
    func flush() async
    /// Stops sending, clears the queue, and forgets the install ID (T43).
    func reset()
}

/// How this install reached the device (D144, spec 11.6). The value is the `channel` field of each event. It is not a
/// purchase and not an ID.
public enum AnalyticsChannel: String, Sendable {
    case appStore = "app_store"
    /// A TestFlight install, or any other install that uses the App Store sandbox, such as App Review.
    case testflight
    /// A Debug build, or a build that Xcode installed.
    case debug
    /// The system gave no answer yet.
    case unknown
}

/// The client of a build with no analytics key. It does nothing (T41).
public struct NullAnalyticsClient: AnalyticsClient {
    public init() {}
    public func capture(_ event: AnalyticsEvent) {}
    public func capture(_ event: AnalyticsEvent, id: UUID, time: Date, acknowledged: @escaping @Sendable () -> Void) {}
    public func flush() async {}
    public func reset() {}
}

/// The choice of the user about analytics, and the default of the region (D051, D052, D078, spec 11.3).
///
/// In the EU, the EEA, the UK, and Switzerland the user opts in first: a one-time question asks, and the switch in
/// settings can turn it on. Elsewhere analytics is on from the start, with no notice, and the switch can turn it off
/// (D078). The region is the region setting of the device (`Locale.current.region`). It is
/// not the place of the user: a traveler, or a device with another region setting, gets the rule of that setting.
/// An unknown region gets the opt-in rule.
public struct AnalyticsPreference {
    private static let enabledKey = "analytics.enabled"
    private static let noticeKey = "analytics.noticeShown"

    /// The EU member states, the other EEA states, the UK, Switzerland, the outermost regions of France, and South Korea.
    static let optInRegions: Set<String> = [
        "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU",
        "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
        "IS", "LI", "NO", "GB", "CH",
        "GF", "GP", "MQ", "RE", "YT", "MF", "AX",
        // Territories with the UK GDPR or a law of the same kind.
        "GI", "JE", "GG", "IM",
        // South Korea: PIPA asks for consent first (D078).
        "KR",
    ]

    public static func requiresOptIn(regionCode: String?) -> Bool {
        guard let regionCode else { return true }
        return optInRegions.contains(regionCode.uppercased())
    }

    private let defaults: UserDefaults
    public let requiresOptIn: Bool

    public init(defaults: UserDefaults = .standard, regionCode: String?) {
        self.defaults = defaults
        requiresOptIn = Self.requiresOptIn(regionCode: regionCode)
    }

    /// `nil` until the user chooses.
    private var choice: Bool? {
        defaults.object(forKey: Self.enabledKey) as? Bool
    }

    public var noticeShown: Bool {
        defaults.bool(forKey: Self.noticeKey)
    }

    /// The value of the switch in settings.
    public var isOn: Bool {
        choice ?? !requiresOptIn
    }

    /// Events leave the device only when this is true. It is the same value as the switch (D078).
    public var isActive: Bool {
        isOn
    }

    /// The opt-in question has not shown yet, and the user did not choose in settings. Only an opt-in region asks.
    public var needsNotice: Bool {
        requiresOptIn && !noticeShown && choice == nil
    }

    public func markNoticeShown() {
        defaults.set(true, forKey: Self.noticeKey)
    }

    /// An explicit choice. It also ends the need for the opt-in question.
    public func set(_ isOn: Bool) {
        defaults.set(isOn, forKey: Self.enabledKey)
        markNoticeShown()
    }
}
