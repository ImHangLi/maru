import Foundation
import MaruCore

/// The one door of analytics for the app (spec 11.3, D051, D052).
///
/// It makes no client, and it sends nothing, until analytics is active: the user opted in, or the region allows the
/// default and the notice showed. A build with no key is not available. It has no switch, no notice, and no client.
/// Turning analytics off stops the client, clears its queue, drops the install ID, and clears the local usage flags (T43).
@MainActor
public final class AnalyticsService {
    private static let usageDayKey = "analytics.usage.day"
    private static let usageFlagsKey = "analytics.usage.flags"
    private static let sinceKey = "analytics.since"

    public let isAvailable: Bool
    private let preference: AnalyticsPreference
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let makeClient: () -> any AnalyticsClient
    private var client: (any AnalyticsClient)?

    public init(
        isAvailable: Bool,
        preference: AnalyticsPreference,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        makeClient: @escaping () -> any AnalyticsClient
    ) {
        self.isAvailable = isAvailable
        self.preference = preference
        self.defaults = defaults
        self.calendar = calendar
        self.makeClient = makeClient
    }

    /// The value of the switch in settings.
    public var isOn: Bool { preference.isOn }
    public var requiresOptIn: Bool { preference.requiresOptIn }
    /// The one-time notice has to show.
    public var needsNotice: Bool { isAvailable && preference.needsNotice }

    private var isActive: Bool { isAvailable && preference.isActive }

    public func noticeDidShow() {
        preference.markNoticeShown()
    }

    /// The choice of the user. Off ends everything that analytics holds on the device (T43).
    public func setOn(_ isOn: Bool) {
        preference.set(isOn)
        guard !isOn else { return }
        // The client can be new in this process, and the install ID of an older run can exist. A new client forgets it.
        (client ?? makeClient()).reset()
        client = nil
        for key in [Self.usageDayKey, Self.usageFlagsKey, Self.sinceKey] {
            defaults.removeObject(forKey: key)
        }
    }

    public func capture(_ event: AnalyticsEvent) {
        guard isActive else { return }
        if client == nil { client = makeClient() }
        client?.capture(event)
    }

    /// Notes that the user used a part of the app today. The flag is one bit for the day. It has no time and no count.
    public func markUsed(_ flag: AnalyticsEvent.UsageFlag, at now: Date = Date()) {
        guard isActive else { return }
        let today = calendar.startOfDay(for: now)
        sendUsage(before: today)
        if defaults.object(forKey: Self.sinceKey) == nil { defaults.set(today, forKey: Self.sinceKey) }
        defaults.set(today, forKey: Self.usageDayKey)
        var flags = Set(defaults.stringArray(forKey: Self.usageFlagsKey) ?? [])
        flags.insert(flag.rawValue)
        defaults.set(flags.sorted(), forKey: Self.usageFlagsKey)
    }

    /// Sends the summary of an earlier day, if one waits. It runs at the start and at each return. A day with no
    /// flag has no summary, and no summary does not mean no intake (spec 11.5).
    public func sendPendingUsage(at now: Date = Date()) {
        guard isActive else { return }
        sendUsage(before: calendar.startOfDay(for: now))
    }

    private func sendUsage(before today: Date) {
        guard let day = defaults.object(forKey: Self.usageDayKey) as? Date, day < today else { return }
        let flags = Set((defaults.stringArray(forKey: Self.usageFlagsKey) ?? []).compactMap(AnalyticsEvent.UsageFlag.init))
        defaults.removeObject(forKey: Self.usageDayKey)
        defaults.removeObject(forKey: Self.usageFlagsKey)
        guard !flags.isEmpty else { return }
        let since = defaults.object(forKey: Self.sinceKey) as? Date ?? day
        let index = calendar.dateComponents([.day], from: since, to: day).day ?? 0
        capture(.dailyUsage(dayIndex: index, used: flags))
    }
}
