#if DEBUG
import Foundation
import MaruCore

/// A result line of the debug menu, or a one-time notice on Today.
struct DebugMessage: Equatable {
    let text: String
    let isProblem: Bool
    /// The menu offers Try Again for the same action.
    var canRetry = false
}

/// What the next launch does with the store.
enum DebugStoreRequest: Equatable {
    case load(DebugScenario)
    case reset
}

extension AppModel {
    /// A store change at the next launch would drop each event that is not confirmed, so the menu refuses
    /// while one is not confirmed or a record transaction runs (D014).
    var debugStoreRefusal: DebugMessage? {
        guard unsavedCount > 0 || !today.inFlight.isEmpty || !today.asNeeded.inFlight.isEmpty else { return nil }
        return DebugMessage(text: "Save or undo the changes that are not saved first.", isProblem: true, canRetry: true)
    }

    /// Writes the request for the next launch and ends the process. The store of a process never changes,
    /// so no read, record, or edit of one store can reach the other one.
    ///
    /// `exit(0)` is not allowed in a release app. This is a debug build only, after an alert that says so.
    /// - Returns: The refusal, when a change is not saved. The process then goes on.
    func closeForDebugStore(_ request: DebugStoreRequest) -> DebugMessage? {
        if let refusal = debugStoreRefusal { return refusal }
        switch request {
        case let .load(scenario): DebugStore.requestLoad(scenario)
        case .reset: DebugStore.requestReset()
        }
        exit(0)
    }

    func showDebugNotice(_ notice: DebugMessage) {
        debugNotice = notice
    }

    /// After a reset, the launch reminder run sets the real reminders again. Today shows its result one time.
    /// "Your reminders are back" shows only when the run confirmed each reminder.
    func debugReconcileDidEnd(_ outcome: (reminders: ReminderOutcome, followUps: FollowUpOutcome?)?) {
        guard DebugStore.launch.didReset, !DebugLaunch.didReportReset else { return }
        DebugLaunch.didReportReset = true
        debugNotice = Self.resetMessage(outcome)
    }

    private static func resetMessage(_ outcome: (reminders: ReminderOutcome, followUps: FollowUpOutcome?)?) -> DebugMessage {
        guard let outcome else {
            return DebugMessage(
                text: "Your real list is back. Maru did not confirm your reminders. It tries again the next time you open it.",
                isProblem: true
            )
        }
        let states = outcome.reminders.schedules.values
        if states.contains(.notSet(.permissionDenied)) {
            return DebugMessage(
                text: "Your real list is back. Notifications are off for Maru, so your reminders cannot show.",
                isProblem: true
            )
        }
        if states.contains(.notSet(.permissionNotAsked)) {
            return DebugMessage(
                text: "Your real list is back. Maru has no notification permission yet, so your reminders cannot show.",
                isProblem: true
            )
        }
        // Follow-ups are extras, and "no room" for one is not a failure. An open removal is.
        let confirmed = states.allSatisfy { $0 == .scheduled || $0 == .off }
            && outcome.followUps.map { !$0.removalPending } == true
        guard confirmed else {
            return DebugMessage(
                text: "Your real list is back. Maru did not confirm all your reminders yet. It tries again the next time you open it.",
                isProblem: true
            )
        }
        return DebugMessage(text: "Your real list is back. Your reminders are back.", isProblem: false)
    }
}
#endif
