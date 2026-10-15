import Foundation

/// One "Remind in 10 min" request of the user: one group of doses, and the instant at which its reminder comes again (D090).
///
/// A group is one series ID and one plan date, so one snooze belongs to one reminder time on one date, as the follow-ups do.
/// The entry holds no item ID, no name, and no dose (spec 10). It is not an intake state and not a record (spec 7.2).
public struct SnoozeEntry: Hashable, Sendable, Codable {
    /// The minutes between the action and the new reminder.
    public static let minutes = 10

    /// `series|<zone or device>|HH:MM`, as in `ReminderRequest.seriesIDKey`.
    public let seriesID: String
    /// The plan date as `YYYY-MM-DD`.
    public let plannedDate: String
    /// The instant at which the snooze request fires.
    public let fireAt: Date

    public init(seriesID: String, plannedDate: String, fireAt: Date) {
        self.seriesID = seriesID
        self.plannedDate = plannedDate
        self.fireAt = fireAt
    }

    /// The same group, whatever the time.
    func isSameGroup(as other: SnoozeEntry) -> Bool {
        seriesID == other.seriesID && plannedDate == other.plannedDate
    }
}

/// Where the snoozes of the user are kept between two runs of the app. The plan owns them: `FollowUpPlan` turns each
/// entry into a request while its group has an open dose, and `FollowUpEngine` removes the entries that no longer stand (D090).
///
/// The value is a preference of the notification system and not health data, so it lives in the App Group defaults and not in
/// the database. It works while the database is locked.
public protocol SnoozeStore: Sendable {
    func load() -> [SnoozeEntry]
    /// Adds the entry. An entry of the same group is replaced, so one group has one snooze.
    func add(_ entry: SnoozeEntry)
    /// Removes these entries. An entry of the same group with another time stays: the user snoozed again after the read.
    func remove(_ entries: [SnoozeEntry])
}

/// A store in memory, for tests and for a process with no saved snoozes.
public final class MemorySnoozeStore: SnoozeStore, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [SnoozeEntry] = []

    public init() {}

    public func load() -> [SnoozeEntry] { lock.withLock { entries } }

    public func add(_ entry: SnoozeEntry) {
        lock.withLock { entries = Self.adding(entry, to: entries) }
    }

    public func remove(_ removed: [SnoozeEntry]) {
        lock.withLock { entries.removeAll { removed.contains($0) } }
    }

    /// The entries after an add. A group has one entry, and the store keeps the newest ones when it holds more than `limit`.
    public static func adding(_ entry: SnoozeEntry, to entries: [SnoozeEntry], limit: Int = 12) -> [SnoozeEntry] {
        let kept = entries.filter { !$0.isSameGroup(as: entry) } + [entry]
        return Array(kept.sorted { $0.fireAt < $1.fireAt }.suffix(limit))
    }
}

extension FollowUpGroup {
    /// The snooze entry belongs to this group. A group with a fixed zone that equals the zone of the device is part of the
    /// series of the device (D047), so a request of that series snoozes it too.
    func isSnoozed(by entry: SnoozeEntry, deviceTimeZone: NamedTimeZone) -> Bool {
        guard entry.plannedDate == dateText else { return false }
        if entry.seriesID == seriesID { return true }
        return seriesTimeZone == deviceTimeZone
            && entry.seriesID == ReminderSeries.identifierPrefix + "device" + String(format: "|%02d:%02d", time.hour, time.minute)
    }

    /// The identifier of the snooze request of the group. It has no `+<minutes>` part, so it never equals a follow-up.
    var snoozeIdentifier: String { identifier + "|snooze" }
}
