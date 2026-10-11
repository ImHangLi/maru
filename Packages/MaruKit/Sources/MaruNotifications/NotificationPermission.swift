import Foundation
import MaruCore
import UserNotifications

/// The notification permission as the settings screen and Today state it (spec 2.2, T13, T14).
///
/// `ReminderAuthorization` joins every state that delivers. The screens must tell a quiet delivery apart.
public enum NotificationPermission: Hashable, Sendable {
    /// The system did not ask yet. Maru asks after the user saves a first reminder (spec 2.2).
    case notAsked
    case denied
    case allowed
    /// Delivered quietly to Notification Center, with no banner and no sound.
    case quiet

    /// Reads the permission now. It never shows the system prompt.
    public static func current() async -> NotificationPermission {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: NotificationPermission(settings.authorizationStatus))
            }
        }
    }

    init(_ status: UNAuthorizationStatus) {
        self = switch status {
        case .notDetermined: .notAsked
        case .denied: .denied
        case .provisional: .quiet
        // Authorized and ephemeral deliver with alerts.
        default: .allowed
        }
    }
}

/// A one-time neutral notification that the user asks for in settings.
///
/// It names no item and no time (spec 8.2). It has one fixed identifier, so a second send replaces the first
/// and never takes more room. The series engine removes only series identifiers, and the follow-up engine only
/// follow-up identifiers, so neither removes it. Both count it as a pending request while it waits.
public enum TestNotification {
    public static let identifier = "test|settings"
    /// The wait before it fires, so the user can lock the iPhone and see it there.
    public static let delay = Duration.seconds(5)

    public enum Result: Hashable, Sendable {
        /// The system holds the request.
        case sent
        /// The permission read did not allow a notification.
        case notAllowed
        /// The system holds reminders up to its limit. A test could push one of them out, so it is not sent.
        case noRoom
        /// The system did not take the request.
        case failed
    }

    /// Sends the test. The caller runs it in the notification queue of the app, so no engine run overlaps it.
    ///
    /// At the system limit it sends nothing. It never removes a reminder to make room: the app can be suspended
    /// before it puts the reminder back, and the reminder would then be lost.
    public static func send(locale: Locale = .current) async -> Result {
        let center = SystemReminderCenter()
        guard await center.authorization() == .authorized else { return .notAllowed }
        let pending = await center.pendingRequests().filter { $0.identifier != identifier }
        guard pending.count < ReminderPlan.systemLimit else { return .noRoom }
        let content = UNMutableNotificationContent()
        content.body = String(
            localized: "This is a test from Maru.",
            bundle: .module,
            locale: locale,
            comment: "The text of the test notification from settings."
        )
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(delay.components.seconds), repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            return .failed
        }
        return .sent
    }

    /// Removes a test that did not fire yet, and reads the pending requests until it is gone. Every reminder
    /// update calls this first, so a test never takes the room of a reminder.
    ///
    /// The reads go on until the test is gone. A test leaves the pending requests at the latest when it fires,
    /// so the reads stop at a deadline of `delay` plus two seconds, and they happen only while a test waits.
    public static func cancel() async {
        let center = SystemReminderCenter()
        guard await center.pendingRequests().contains(where: { $0.identifier == identifier }) else { return }
        await center.remove(identifiers: [identifier])
        let deadline = ContinuousClock.now + delay + .seconds(2)
        while ContinuousClock.now < deadline {
            if !(await center.pendingRequests()).contains(where: { $0.identifier == identifier }) { return }
            try? await Task.sleep(for: ReminderEngine.removalWait)
        }
    }
}
