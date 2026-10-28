import Foundation

/// What the user can do on a reminder (spec 8.3, D034, D090).
public enum ReminderActionKind: String, CaseIterable, Hashable, Sendable {
    /// "Taken" for one item, "Take All" for a reminder that names several items. The identifier is the same for both.
    case taken = "reminder.taken"
    /// "Skip" for one item, "Skip All" for a reminder that names several items.
    case skip = "reminder.skip"
    /// "Remind in 10 min". It writes no record (spec 7.2).
    case snooze = "reminder.snooze"
}

/// The set of actions that a request has. The system looks the category up by its identifier when it shows the notification,
/// so each identifier names one fixed set of actions (D090). One registry in `MaruNotifications` registers every case.
public enum ReminderCategory: String, CaseIterable, Hashable, Sendable {
    /// The request names one item, or its group has one item: "Taken", "Skip", and "Remind in 10 min" (D034).
    case single = "reminder.single.v2"
    /// The request names two or more items of one member, and the names are shown: "Take All", "Skip All", and "Remind in 10 min" (D090, D123).
    /// With the names hidden the user cannot see what the action records, so such a request has no group action.
    case group = "reminder.group.v2"
    /// Any other request: only "Remind in 10 min". A snooze writes no record.
    case snooze = "reminder.snooze.v2"

    public var actions: [ReminderActionKind] {
        switch self {
        case .single, .group: [.taken, .skip, .snooze]
        case .snooze: [.snooze]
        }
    }

    /// The category of a request that names `named` open items.
    ///
    /// - Parameters:
    ///   - named: How many open items the request names.
    ///   - showsNames: The text names the items (D029). A group action needs this.
    ///   - singleItem: The request stands for one item: a first reminder that names one item, or a follow-up of a group
    ///     that has one item (D034). The names can be hidden, as before.
    ///   - membersCount: How many members of the Family own the named items. A request that names doses of two or more members
    ///     has no group action, because one tap must not record a dose for another member (D123).
    static func choose(named: Int, showsNames: Bool, singleItem: Bool, membersCount: Int = 1) -> ReminderCategory {
        if singleItem { return .single }
        if membersCount >= 2 { return .snooze }
        return named >= 2 && showsNames ? .group : .snooze
    }
}

/// The interruption level of a request. Maru uses the highest level that needs no special entitlement (D062).
public enum ReminderLevel: Hashable, Sendable {
    /// Every level that is not time sensitive. A request from a build before D062 has it.
    case active
    /// The reminder shows during a Focus, unless the user turns off Time Sensitive alerts for Maru (D062).
    case timeSensitive
}

/// How a request looks and acts: its category and its level. The engines compare it with the value that the system holds,
/// so a change of either value replaces the pending request (D090).
public struct ReminderPresentation: Hashable, Sendable {
    public let category: ReminderCategory
    public let level: ReminderLevel

    public init(category: ReminderCategory, level: ReminderLevel = .timeSensitive) {
        self.category = category
        self.level = level
    }
}

extension PendingReminder {
    /// The request that the system holds is the request that the plan wants: the same `userInfo`, text, category, and level.
    /// This is the one comparison of both engines (D090). A request from a build before the category set has no known category,
    /// so it is never current, and the first run replaces it.
    public func isCurrent(userInfo wantedInfo: [String: String], text wantedText: ReminderText, presentation wanted: ReminderPresentation) -> Bool {
        userInfo == wantedInfo && text == wantedText && presentation == wanted
    }
}
