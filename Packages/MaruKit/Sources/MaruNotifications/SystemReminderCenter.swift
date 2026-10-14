import Foundation
import MaruCore
import UserNotifications

/// The notification center of the system as a `ReminderCenter`.
///
/// It only translates. `ReminderPlan` and `ReminderEngine` in `MaruCore` have every rule.
/// Each call reads a value type from the system objects before it returns, so no system object leaves the call.
public struct SystemReminderCenter: ReminderCenter {
    public init() {}

    public func authorization() async -> ReminderAuthorization {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: ReminderAuthorization(settings.authorizationStatus))
            }
        }
    }

    public func requestAuthorization() async -> ReminderAuthorization {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            // The answer comes from the settings below. An error here means that the user gets no prompt.
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                continuation.resume()
            }
        }
        return await authorization()
    }

    public func pendingRequests() async -> [PendingReminder] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map { PendingReminder($0) })
            }
        }
    }

    public func add(_ request: ReminderRequest) async throws {
        let request = UNNotificationRequest(request)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                continuation.resume(with: error.map(Result.failure) ?? .success(()))
            }
        }
    }

    public func remove(identifiers: [String]) async {
        // The system removes the requests after this call returns. The engine reads the pending requests to see the result.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func text(for content: ReminderContent) -> ReminderText {
        content.text(locale: .current)
    }
}

extension ReminderAuthorization {
    init(_ status: UNAuthorizationStatus) {
        self = switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        // Authorized, provisional, and ephemeral all deliver. The engine checks each request after it adds it.
        default: .authorized
        }
    }
}

extension UNNotificationRequest {
    /// A calendar request: it repeats, or it fires one time on its date (D036).
    /// The text is fixed here, in the language of now (spec 8.2, D029).
    convenience init(_ request: ReminderRequest, locale: Locale = .current) {
        let content = UNMutableNotificationContent()
        let text = request.content.text(locale: locale)
        content.title = text.title
        content.body = text.body
        content.sound = .default
        // A reminder shows during a Focus, unless the user turns off Time Sensitive alerts for Maru (D062).
        content.interruptionLevel = .timeSensitive
        content.userInfo = request.userInfo
        if request.content.hasTakenAction { content.categoryIdentifier = ReminderAction.categoryIdentifier }
        self.init(
            identifier: request.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: request.trigger.dateComponents, repeats: request.trigger.repeats
            )
        )
    }
}

extension PendingReminder {
    init(_ request: UNNotificationRequest, deliveredAt: Date? = nil) {
        self.init(
            identifier: request.identifier,
            userInfo: request.content.userInfo as? [String: String] ?? [:],
            text: ReminderText(title: request.content.title, body: request.content.body),
            hasTakenAction: request.content.categoryIdentifier == ReminderAction.categoryIdentifier,
            isTimeSensitive: request.content.interruptionLevel == .timeSensitive,
            deliveredAt: deliveredAt
        )
    }
}

extension ReminderContent {
    /// The body names at most this many items. A longer list names the first ones and the count of the others,
    /// so the lock screen shows the whole text.
    static let listedNames = 3

    /// The text of the reminder from the String Catalog of this target (D029). It never says that a dose
    /// is not taken, because the user can record before the time (spec 8.2). It has no clock time:
    /// the system shows the delivery time.
    func text(locale: Locale) -> ReminderText {
        let title = switch kind {
        case .due:
            String(localized: "Time to take", bundle: .module, locale: locale, comment: "The title of a reminder.")
        case .again:
            String(localized: "No record yet", bundle: .module, locale: locale, comment: "The title of a follow-up reminder.")
        }
        guard var names, !names.isEmpty else {
            let body = String(
                localized: "Open Maru to see your plan.",
                bundle: .module,
                locale: locale,
                comment: "The body of a reminder with the item names turned off."
            )
            return ReminderText(title: title, body: body)
        }
        if names.count > Self.listedNames {
            let more = String(
                localized: "\(names.count - Self.listedNames + 1) more",
                bundle: .module,
                locale: locale,
                comment: "The last entry of a list of item names in a reminder, for example “Zinc, Creatine, and 2 more”. The placeholder is the number of items not named."
            )
            names = names.prefix(Self.listedNames - 1) + [more]
        }
        return ReminderText(title: title, body: names.formatted(.list(type: .and).locale(locale)))
    }
}
