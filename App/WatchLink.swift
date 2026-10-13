import Foundation
import MaruCore
import WatchConnectivity

/// The link to the Watch app (D071). It sends the list of today, and it gives each request of the Watch
/// to the model. It holds no data. An iPhone with no paired Watch, or with no Watch app, sends nothing.
final class WatchLink: NSObject, WCSessionDelegate, Sendable {
    static let shared = WatchLink()

    /// Call it at each launch, so a request that starts Maru in the background reaches the model.
    /// The activation does not block, so the launch does not wait for it (spec 9).
    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    var hasWatchApp: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    /// Replaces the list that the Watch opens with. The system keeps only the last one and delivers it
    /// when the Watch can take it.
    func send(_ day: WatchDay) {
        guard hasWatchApp, let message = day.message else { return }
        try? WCSession.default.updateApplicationContext([WatchDay.contextKey: message])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        Task { @MainActor in AppModel.shared.sendWatchDay() }
    }

    /// The user installed the Watch app, or paired a Watch.
    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in AppModel.shared.sendWatchDay() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user changed to another Watch. The session needs a new activation for it.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        // The handler is not Sendable. It runs one time.
        nonisolated(unsafe) let replyHandler = replyHandler
        Task { @MainActor in
            replyHandler(await AppModel.shared.answerWatch(messageData))
        }
    }
}
