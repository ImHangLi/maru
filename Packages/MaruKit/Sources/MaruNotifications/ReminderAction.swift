import Foundation
import MaruCore
import UserNotifications

/// The "Taken" action of a reminder that stands for exactly one item (spec 8.3, D034).
public enum ReminderAction {
    /// The category of a request with the action. A request for two or more items has no category.
    public static let categoryIdentifier = "reminder.single"
    /// The `actionIdentifier` of the response when the user chooses "Taken".
    public static let takenIdentifier = "reminder.taken"

    /// Registers the category. Call it at each launch, before the system can deliver a response.
    ///
    /// On the iPhone the action needs an unlock, so a person who holds a locked iPhone cannot write a record.
    /// On a Watch that the user wears, the action runs with the iPhone locked, and the database is readable
    /// after the first unlock (D066).
    /// It has no foreground option, so the system starts Maru in the background for the record.
    public static func register(locale: Locale = .current) {
        let taken = UNNotificationAction(
            identifier: takenIdentifier,
            title: String(
                localized: "Taken",
                bundle: .module,
                locale: locale,
                comment: "The action of a reminder for one item. It records the item as taken."
            ),
            options: [.authenticationRequired]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier, actions: [taken], intentIdentifiers: [], options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}

/// A notification that tells the user that the "Taken" action recorded nothing (D034).
///
/// The system runs the action in the background and removes the reminder. Maru can not come to the front
/// by itself, so without this notification the user would see no result. It names no item (spec 10).
/// It has one fixed identifier, so a second one replaces the first. It has no trigger, so the system
/// delivers it at once. The engines remove only their own identifiers, so neither removes it.
public enum ActionNotice {
    public static let identifier = "action|notRecorded"

    /// Why the action recorded nothing (D089). The body says it in one line.
    public enum Reason: Sendable {
        /// The reminder does not match exactly one open dose of today: another day, an older plan, a dose with a record,
        /// or a late delivery.
        case noMatch
        /// The database did not read or did not commit.
        case notSaved
    }

    public static func send(_ reason: Reason, locale: Locale = .current) async {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Not recorded",
            bundle: .module,
            locale: locale,
            comment: "The title of the notification after the Taken action of a reminder recorded nothing."
        )
        switch reason {
        case .noMatch:
            content.body = String(
                localized: "This reminder no longer matches one dose of today. Open Maru to record it.",
                bundle: .module,
                locale: locale,
                comment: "The body of the notification after the Taken action of a reminder recorded nothing, because the reminder does not match exactly one open dose of today."
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
