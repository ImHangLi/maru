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
