import Foundation
import MaruCore
import UserNotifications
import os

/// The notification center of the system as a `ReminderCenter`.
///
/// It only translates. `ReminderPlan` and `ReminderEngine` in `MaruCore` have every rule.
/// Each call reads a value type from the system objects before it returns, so no system object leaves the call.
public struct SystemReminderCenter: ReminderCenter {
    /// The file name of the reminder sound in the app bundle, or `nil` for the default sound of the system (D112).
    /// Each call reads it again, so a run uses the sound of now.
    let sound: @Sendable () -> String?

    public init(sound: @escaping @Sendable () -> String? = { nil }) {
        self.sound = sound
    }

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
        let sound = sound()
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map { PendingReminder($0, currentSound: sound) })
            }
        }
    }

    public func add(_ request: ReminderRequest) async throws {
        let request = UNNotificationRequest(request, sound: sound())
        try await Self.submit(request)
    }

    /// The system refused the request. The engine goes on with the others and reports this schedule as not set (D088).
    /// The log has the error domain and code and nothing else: no identifier, name, dose, or time (spec 10).
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Maru", category: "reminders")

    static func submit(_ request: UNNotificationRequest) async throws {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                UNUserNotificationCenter.current().add(request) { error in
                    continuation.resume(with: error.map(Result.failure) ?? .success(()))
                }
            }
        } catch {
            let error = error as NSError
            log.error("The system refused a request. Error: \(error.domain, privacy: .public) \(error.code, privacy: .public)")
            throw error
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
    convenience init(_ request: ReminderRequest, locale: Locale = .current, sound: String? = nil) {
        self.init(
            identifier: request.identifier,
            content: UNMutableNotificationContent.reminder(
                request.content, userInfo: request.userInfo, threadIdentifier: nil, locale: locale, sound: sound
            ),
            trigger: UNCalendarNotificationTrigger(
                dateMatching: request.trigger.dateComponents, repeats: request.trigger.repeats
            )
        )
    }
}

extension UNMutableNotificationContent {
    /// The `userInfo` key of the sound file of a request (D112). The system does not tell the sound of a pending request,
    /// so the request keeps its name here. A request with the default sound has no such key.
    static let soundKey = "maru.sound"

    /// The one place that turns a `ReminderContent` into the content of the system: the text, the sound, the level, the
    /// category, and the `userInfo`. The two request types use it (D090).
    ///
    /// - Parameter sound: A sound file in the app bundle, or `nil` for the default sound of the system (D112).
    static func reminder(
        _ reminder: ReminderContent, userInfo: [String: String], threadIdentifier: String?, locale: Locale, sound: String?
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let text = reminder.text(locale: locale)
        content.title = text.title
        content.body = text.body
        var userInfo = userInfo
        if let sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
            userInfo[soundKey] = sound
        } else {
            content.sound = .default
        }
        content.interruptionLevel = reminder.presentation.level.system
        content.categoryIdentifier = reminder.presentation.category.rawValue
        content.userInfo = userInfo
        if let threadIdentifier { content.threadIdentifier = threadIdentifier }
        return content
    }
}

extension ReminderLevel {
    /// A reminder shows during a Focus, unless the user turns off Time Sensitive alerts for Maru (D062).
    var system: UNNotificationInterruptionLevel {
        switch self {
        case .timeSensitive: .timeSensitive
        case .active: .active
        }
    }

    init(_ level: UNNotificationInterruptionLevel) {
        self = level == .timeSensitive ? .timeSensitive : .active
    }
}

extension PendingReminder {
    /// - Parameter currentSound: The sound of now. A pending request with another sound stays current, and the engines give
    ///   it the sound of now with an add that keeps it until the system holds the new one (D112). A delivered
    ///   notification has no check.
    init(_ request: UNNotificationRequest, deliveredAt: Date? = nil, currentSound: String?? = .none) {
        var userInfo = request.content.userInfo as? [String: String] ?? [:]
        let sound = userInfo.removeValue(forKey: UNMutableNotificationContent.soundKey)
        self.init(
            identifier: request.identifier,
            userInfo: userInfo,
            text: ReminderText(title: request.content.title, body: request.content.body),
            // A category that this build does not register is not a presentation that the engines can keep.
            presentation: ReminderCategory(rawValue: request.content.categoryIdentifier).map {
                ReminderPresentation(category: $0, level: ReminderLevel(request.content.interruptionLevel))
            },
            deliveredAt: deliveredAt,
            hasCurrentSound: currentSound.map { $0 == sound } ?? true
        )
    }
}

extension ReminderContent {
    /// The body names at most this many items. A longer list names the first ones and the count of the others,
    /// so the lock screen shows the whole text. A reminder with group actions is the exception: it names every item.
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
        // A reminder with group actions names every item: the user must see each dose that the action records (D090).
        if names.count > Self.listedNames, category != .group {
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
