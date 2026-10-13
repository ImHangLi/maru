import MaruCore
import MaruNotifications
import UserNotifications
import os

/// Receives a tap on a delivered reminder, or its "Taken" action, and gives it to the model (spec 8.3, D034).
///
/// The system keeps a weak reference to its delegate, so the app keeps this object.
final class ReminderTapDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    private let open: @MainActor @Sendable (DeliveredReminder) -> Void
    /// The system gives a background action a short time, and Apple states no number. The delegate returns to
    /// the system after this time at the latest. A record that runs then still ends by its own rules.
    private static let actionLimit = Duration.seconds(5)

    /// The "Taken" action. It returns when the record commits or fails.
    private let take: @MainActor @Sendable (DeliveredReminder) async -> Void
    #if DEBUG
    /// Opens Today with no reminder, for a tap on a notification of the other debug store.
    private let showToday: @MainActor @Sendable () -> Void

    init(
        open: @escaping @MainActor @Sendable (DeliveredReminder) -> Void,
        take: @escaping @MainActor @Sendable (DeliveredReminder) async -> Void,
        showToday: @escaping @MainActor @Sendable () -> Void
    ) {
        self.open = open
        self.take = take
        self.showToday = showToday
    }
    #else
    init(
        open: @escaping @MainActor @Sendable (DeliveredReminder) -> Void,
        take: @escaping @MainActor @Sendable (DeliveredReminder) async -> Void
    ) {
        self.open = open
        self.take = take
    }
    #endif

    /// Every notification of Maru also shows while Maru is in front. With no options, the system drops it
    /// with no banner, no sound, and no entry in Notification Center, so a reminder at its time would be lost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// The completion handler must run on the main thread. UIKit asserts this and stops the app. The async form
    /// of this method calls it from a background thread, so a tap on a reminder closed Maru.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // The system objects are not Sendable. The response does not change, and the handler runs one time.
        nonisolated(unsafe) let response = response
        nonisolated(unsafe) let completionHandler = completionHandler
        Task { @MainActor in
            await handle(response)
            completionHandler()
        }
    }

    private func handle(_ response: UNNotificationResponse) async {
        // A tap on the reminder opens it. "Taken" records its one dose in the background (spec 8.3, D034).
        let isTaken = response.actionIdentifier == ReminderAction.takenIdentifier
        guard isTaken || response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        // The "not recorded" notice is not a reminder. A tap only opens the app.
        guard response.notification.request.identifier != ActionNotice.identifier else { return }
        let notification = response.notification
        #if DEBUG
        // A notification from before the latest store change belongs to the other store (spec 7.3).
        guard !DebugStore.precedesTransition(notification.date) else {
            await showToday()
            return
        }
        #endif
        let trigger = notification.request.trigger as? UNCalendarNotificationTrigger
        var userInfo: [String: String] = [:]
        for case let (key as String, value as String) in notification.request.content.userInfo {
            userInfo[key] = value
        }
        let reminder = DeliveredReminder(
            // The delivery date, never the tap time, as a planned time or an intake time (spec 8.3).
            deliveredAt: notification.date,
            userInfo: userInfo,
            // `nil` is a request that fires every day.
            triggerWeekday: trigger?.dateComponents.weekday.flatMap(Weekday.init(calendarWeekday:))
        )
        if isTaken {
            // Return to the system when the record ends or at the limit, the first of the two. The record is not
            // cancelled at the limit: a cancelled write could leave an event that Maru does not know.
            let take = take
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let end = ActionEnd(continuation)
                Task {
                    await take(reminder)
                    end.finish()
                }
                Task {
                    try? await Task.sleep(for: ReminderTapDelegate.actionLimit)
                    end.finish()
                }
            }
        } else {
            await open(reminder)
        }
    }
}

/// Returns to the system one time: the first `finish` resumes the continuation, and a later one does nothing.
private final class ActionEnd: Sendable {
    private let waiting: OSAllocatedUnfairLock<CheckedContinuation<Void, Never>?>

    init(_ continuation: CheckedContinuation<Void, Never>) {
        waiting = OSAllocatedUnfairLock(initialState: continuation)
    }

    func finish() {
        let continuation = waiting.withLock { held -> CheckedContinuation<Void, Never>? in
            defer { held = nil }
            return held
        }
        continuation?.resume()
    }
}
