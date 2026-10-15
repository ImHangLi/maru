import Foundation
import MaruCore
import UserNotifications

/// The one registry of the notification categories of Maru, and their actions (spec 8.3, D034, D090).
///
/// `setNotificationCategories` replaces the whole set, so this is the only place that calls it, with every category.
public enum ReminderAction {
    /// Registers every category. Call it at each launch, before the system can deliver a response.
    ///
    /// On the iPhone a record action needs an unlock, so a person who holds a locked iPhone cannot write a record.
    /// On a Watch that the user wears, the action runs with the iPhone locked, and the database is readable
    /// after the first unlock (D066). "Remind in 10 min" writes no record, so it needs no unlock.
    /// No action has a foreground option, so the system starts Maru in the background for it.
    public static func register(locale: Locale = .current) {
        UNUserNotificationCenter.current().setNotificationCategories(Set(ReminderCategory.allCases.map { category($0, locale: locale) }))
    }

    static func category(_ category: ReminderCategory, locale: Locale) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: category.rawValue,
            actions: category.actions.map { action($0, in: category, locale: locale) },
            intentIdentifiers: [],
            options: []
        )
    }

    static func action(_ kind: ReminderActionKind, in category: ReminderCategory, locale: Locale) -> UNNotificationAction {
        let isGroup = category == .group
        let title: String
        switch kind {
        case .taken:
            title = isGroup
                ? String(
                    localized: "Take All", bundle: .module, locale: locale,
                    comment: "The action of a reminder for several items. It records every open item that the reminder names as taken."
                )
                : String(
                    localized: "Taken", bundle: .module, locale: locale,
                    comment: "The action of a reminder for one item. It records the item as taken."
                )
        case .skip:
            title = isGroup
                ? String(
                    localized: "Skip All", bundle: .module, locale: locale,
                    comment: "The action of a reminder for several items. It records every open item that the reminder names as skipped."
                )
                : String(
                    localized: "Skip", bundle: .module, locale: locale,
                    comment: "The action of a reminder for one item. It records the item as skipped."
                )
        case .snooze:
            title = String(
                localized: "Remind in 10 min", bundle: .module, locale: locale,
                comment: "The action of a reminder. It makes the reminder come again in ten minutes. It records nothing."
            )
        }
        return UNNotificationAction(
            identifier: kind.rawValue,
            title: title,
            // A record writes health data, so it needs an unlock. A snooze does not.
            options: kind == .snooze ? [] : [.authenticationRequired]
        )
    }
}

/// A notification that tells the user that the action of a reminder recorded nothing, or not everything (D034, D090).
///
/// The system runs the action in the background and removes the reminder. Maru can not come to the front
/// by itself, so without this notification the user would see no result. It names no item (spec 10).
/// It has one fixed identifier, so a second one replaces the first. It has no trigger, so the system
/// delivers it at once. The engines remove only their own identifiers, so neither removes it.
public enum ActionNotice {
    public static let identifier = "action|notRecorded"

    /// Why the action recorded nothing, or not everything (D089, D090). The body says it in one line.
    public enum Reason: Sendable, Equatable {
        /// The reminder does not match an open dose of today: another day, an older plan, a dose with a record,
        /// or a late delivery.
        case noMatch
        /// The database did not read or did not commit.
        case notSaved
        /// A group action recorded some of the doses that the reminder names, and the others failed the checks of their own.
        case partial(recorded: Int, of: Int)
        /// "Remind in 10 min" found no group of today that it can remind again.
        case snoozeFailed
    }

    public static func send(_ reason: Reason, locale: Locale = .current) async {
        let content = UNMutableNotificationContent()
        content.title = switch reason {
        case .partial:
            String(
                localized: "Partly recorded",
                bundle: .module,
                locale: locale,
                comment: "The title of the notification after the Take All or Skip All action of a reminder recorded some doses and not all."
            )
        case .snoozeFailed:
            String(
                localized: "Reminder not set",
                bundle: .module,
                locale: locale,
                comment: "The title of the notification after the Remind in 10 min action of a reminder could not set a new reminder."
            )
        case .noMatch, .notSaved:
            String(
                localized: "Not recorded",
                bundle: .module,
                locale: locale,
                comment: "The title of the notification after the Taken action of a reminder recorded nothing."
            )
        }
        switch reason {
        case .noMatch:
            content.body = String(
                localized: "This reminder no longer matches one dose of today. Open Maru to record it.",
                bundle: .module,
                locale: locale,
                comment: "The body of the notification after the Taken action of a reminder recorded nothing, because the reminder does not match exactly one open dose of today."
            )
        case let .partial(recorded, total):
            content.body = String(
                localized: "\(recorded) of \(total) recorded. Open Maru to check the rest.",
                bundle: .module,
                locale: locale,
                comment: "The body of the notification after the Take All or Skip All action of a reminder recorded some doses and not all. The first placeholder is the number of doses recorded, the second is the number that the reminder names."
            )
        case .snoozeFailed:
            content.body = String(
                localized: "This reminder no longer matches a dose of today. Open Maru to see your plan.",
                bundle: .module,
                locale: locale,
                comment: "The body of the notification after the Remind in 10 min action of a reminder could not set a new reminder, because the reminder does not match a dose of today or the time for reminders of that dose is over."
            )
        case .notSaved:
            content.body = String(
                localized: "Maru could not save the dose. Open Maru to try again.",
                bundle: .module,
                locale: locale,
                comment: "The body of the notification after the Taken action of a reminder recorded nothing, because the record did not save."
            )
        }
        content.sound = .default
        // An error leaves no notification. Maru still shows the state when the user opens it.
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
    }

    /// Removes the notification when the user opens Maru.
    public static func clear() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
