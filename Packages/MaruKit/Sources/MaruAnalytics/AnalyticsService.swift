import Foundation
import MaruCore

/// The one door of analytics for the app (spec 11.3, D051, D052).
///
/// It makes no client, and it sends nothing, until analytics is active: the user opted in, or the region has the default
/// "on" (D078). A build with no key is not available. It has no switch, no question, and no client.
/// Turning analytics off stops the client, clears its queue, drops the install ID, and clears the local usage state (T43).
@MainActor
public final class AnalyticsService {
    private static let usageDayKey = "analytics.usage.day"
    private static let usageFlagsKey = "analytics.usage.flags"
    private static let usageOpensKey = "analytics.usage.opens"
    private static let usageItemsKey = "analytics.usage.items"
    private static let usageWidgetKey = "analytics.usage.widget"
    private static let usageFamilyKey = "analytics.usage.family"
    private static let usageProKey = "analytics.usage.pro"
    private static let sinceKey = "analytics.since"
    private static let usagePendingKey = "analytics.usage.pending"
    private static let permissionKey = "analytics.permission"
    private static let localKeys = [
        usageDayKey, usageFlagsKey, usageOpensKey, usageItemsKey, usageWidgetKey, usageFamilyKey, usageProKey, usagePendingKey,
        sinceKey, permissionKey,
    ]

    /// The summary of an ended day that waits for the next open of the app. It has no time.
    private struct PendingDay: Codable {
        let dayIndex: Int
        let flags: [String]
        let opens: Int
        let items: Int?
        let widget: Bool?
        let family: Int?
        let pro: AnalyticsEvent.ProUse?
    }

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
    /// The one-time opt-in question has to show. Only an opt-in region has it (D078).
    public var needsNotice: Bool { isAvailable && preference.needsNotice }

    /// Analytics may collect now: the build has a key, and the consent rule allows it.
    public var isActive: Bool { isAvailable && preference.isActive }

    public func noticeDidShow() {
        preference.markNoticeShown()
    }

    /// The choice of the user. Off ends everything that analytics holds on the device (T43).
    public func setOn(_ isOn: Bool) {
        preference.set(isOn)
        // The user is in the app now, so this day counts one open (D077).
        guard !isOn else { return noteOpen() }
        // The client can be new in this process, and the install ID of an older run can exist. A new client forgets it.
        (client ?? makeClient()).reset()
        client = nil
        for key in Self.localKeys {
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
        startDay(at: now)
        var flags = Set(defaults.stringArray(forKey: Self.usageFlagsKey) ?? [])
        flags.insert(flag.rawValue)
        defaults.set(flags.sorted(), forKey: Self.usageFlagsKey)
    }

    /// Counts one time that the app came to the front today. The summary sends only a bucket of the count.
    public func noteOpen(at now: Date = Date()) {
        guard isActive else { return }
        startDay(at: now)
        defaults.set(defaults.integer(forKey: Self.usageOpensKey) + 1, forKey: Self.usageOpensKey)
    }

    /// Keeps the number of active items of the last read today. The summary sends only a bucket of it.
    public func noteActiveItems(_ count: Int, at now: Date = Date()) {
        guard isActive, hasDay(at: now) else { return }
        defaults.set(max(count, 0), forKey: Self.usageItemsKey)
    }

    /// Keeps the number of active members of the Family at the last read today. The summary sends only a bucket of it (D121).
    public func noteFamilySize(_ count: Int, at now: Date = Date()) {
        guard isActive, hasDay(at: now) else { return }
        defaults.set(max(count, 0), forKey: Self.usageFamilyKey)
    }

    /// Keeps the Pro plan and the Pro features in use at the last check today (D127).
    public func noteProUse(_ use: AnalyticsEvent.ProUse, at now: Date = Date()) {
        guard isActive, hasDay(at: now), let data = try? JSONEncoder().encode(use) else { return }
        defaults.set(data, forKey: Self.usageProKey)
    }

    /// Keeps whether a widget of Maru is on the Home Screen, at the last check today.
    public func noteWidget(installed: Bool, at now: Date = Date()) {
        guard isActive, hasDay(at: now) else { return }
        defaults.set(installed, forKey: Self.usageWidgetKey)
    }

    /// Sends a `notification_permission` event when the permission differs from the one that was sent last.
    /// The first read after analytics became active sends the state with `unknown` as the previous state.
    public func notePermission(_ state: AnalyticsEvent.Permission) {
        guard isActive else { return }
        let previous = defaults.string(forKey: Self.permissionKey).flatMap(AnalyticsEvent.Permission.init)
        guard previous != state else { return }
        defaults.set(state.rawValue, forKey: Self.permissionKey)
        capture(.notificationPermission(state, previous: previous))
    }

    /// Sends the summary of an earlier day, if one waits. Only the start and each return of the app call it, so
    /// the time of the event is the time of an open, never the time of a background record (D077). A day with no
    /// open and no flag has no summary, and no summary does not mean no intake (spec 11.5).
    public func sendPendingUsage(at now: Date = Date()) {
        guard isActive else { return }
        endDay(before: calendar.startOfDay(for: now))
        guard let data = defaults.data(forKey: Self.usagePendingKey) else { return }
        defaults.removeObject(forKey: Self.usagePendingKey)
        guard let day = try? JSONDecoder().decode(PendingDay.self, from: data) else { return }
        capture(.dailyUsage(
            dayIndex: day.dayIndex,
            AnalyticsEvent.UsageDay(
                used: Set(day.flags.compactMap(AnalyticsEvent.UsageFlag.init)),
                opens: day.opens,
                activeItems: day.items,
                hasWidget: day.widget,
                familySize: day.family,
                pro: day.pro
            )
        ))
    }

    /// The day of the tallies is today. The tallies of an earlier day wait for the next open.
    private func startDay(at now: Date) {
        let today = calendar.startOfDay(for: now)
        endDay(before: today)
        if defaults.object(forKey: Self.sinceKey) == nil { defaults.set(today, forKey: Self.sinceKey) }
        defaults.set(today, forKey: Self.usageDayKey)
    }

    /// A count or a check belongs to a day that has an open or a flag, so it alone makes no summary.
    private func hasDay(at now: Date) -> Bool {
        guard let day = defaults.object(forKey: Self.usageDayKey) as? Date else { return false }
        return day == calendar.startOfDay(for: now)
    }

    /// Moves the tallies of an earlier day into the one waiting summary. A newer day replaces an older one that
    /// still waits, so at most one summary stays on the device.
    private func endDay(before today: Date) {
        guard let day = defaults.object(forKey: Self.usageDayKey) as? Date, day < today else { return }
        let flags = Set((defaults.stringArray(forKey: Self.usageFlagsKey) ?? []).compactMap(AnalyticsEvent.UsageFlag.init))
        let opens = defaults.integer(forKey: Self.usageOpensKey)
        let items = defaults.object(forKey: Self.usageItemsKey) as? Int
        let widget = defaults.object(forKey: Self.usageWidgetKey) as? Bool
        let family = defaults.object(forKey: Self.usageFamilyKey) as? Int
        let pro = defaults.data(forKey: Self.usageProKey).flatMap { try? JSONDecoder().decode(AnalyticsEvent.ProUse.self, from: $0) }
        for key in [
            Self.usageDayKey, Self.usageFlagsKey, Self.usageOpensKey, Self.usageItemsKey, Self.usageWidgetKey, Self.usageFamilyKey,
            Self.usageProKey,
        ] {
            defaults.removeObject(forKey: key)
        }
        guard !flags.isEmpty || opens > 0 else { return }
        let since = defaults.object(forKey: Self.sinceKey) as? Date ?? day
        let index = calendar.dateComponents([.day], from: since, to: day).day ?? 0
        let pending = PendingDay(
            dayIndex: index, flags: flags.map(\.rawValue).sorted(), opens: opens, items: items, widget: widget, family: family, pro: pro
        )
        if let data = try? JSONEncoder().encode(pending) { defaults.set(data, forKey: Self.usagePendingKey) }
    }
}
