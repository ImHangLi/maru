import Foundation
import MaruCore
import WatchConnectivity

/// The link to the iPhone app (D071). It gives each list that the iPhone sends, and it sends the requests.
final class PhoneLink: NSObject, WCSessionDelegate, Sendable {
    enum Answer: Sendable {
        case reply(WatchReply)
        /// The request did not leave the Watch, so the iPhone recorded nothing.
        case notReachable
        /// The request left, and no reply that the Watch can read came. The iPhone can have the record.
        case noAnswer
    }

    /// Each list from the iPhone: the application context, also the one from before this launch, and the replies
    /// to `refresh`.
    let days: AsyncStream<WatchDay>
    private let incoming: AsyncStream<WatchDay>.Continuation

    override init() {
        let (days, incoming) = AsyncStream<WatchDay>.makeStream()
        self.days = days
        self.incoming = incoming
        super.init()
    }

    func activate() {
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Asks the iPhone for the list of now. The system starts Maru on the iPhone in the background for it.
    func refresh() {
        Task {
            if case let .reply(reply) = await send(.today), let day = reply.day {
                incoming.yield(day)
            }
        }
    }

    func send(_ request: WatchRequest) async -> Answer {
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable, let message = request.message else {
            return .notReachable
        }
        // The system calls exactly one of the two handlers.
        return await withCheckedContinuation { continuation in
            session.sendMessageData(message) { reply in
                continuation.resume(returning: WatchReply(message: reply).map(Answer.reply) ?? .noAnswer)
            } errorHandler: { error in
                continuation.resume(returning: (error as? WCError)?.code == .notReachable ? .notReachable : .noAnswer)
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        show(session.receivedApplicationContext)
        refresh()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        show(applicationContext)
    }

    private func show(_ context: [String: Any]) {
        if let day = (context[WatchDay.contextKey] as? Data).flatMap(WatchDay.init(message:)) {
            incoming.yield(day)
        }
    }
}
