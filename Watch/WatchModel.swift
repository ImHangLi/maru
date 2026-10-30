import Foundation
import MaruCore
import Observation

/// The state of the Watch app (D071). The view reads it and calls its operations (spec 6).
///
/// The Watch has no database. It never changes the state of a dose by itself: the list changes only when
/// the iPhone sends a new one, so a dose shows as recorded only after the iPhone committed it (spec 7.2).
@MainActor
@Observable
final class WatchModel {
    /// Why the last request recorded nothing that the Watch knows of.
    enum Notice: Equatable {
        /// The request did not leave the Watch.
        case notReachable
        /// The request left, and no reply came. The iPhone can have the record.
        case notConfirmed
        /// The iPhone answered that the dose is not the one that the Watch showed. It recorded nothing.
        case changed
        /// The iPhone answered that it recorded nothing, and it sent its list.
        case notRecorded
        /// The iPhone answered that it recorded nothing, and it could not read its data. The usual cause:
        /// the iPhone restarted, and the database is protected until the first unlock (spec 10, D066).
        case locked
    }

    /// The answer to "Open on iPhone" on the locked screen (D111).
    enum ProRequest: Equatable {
        case sending
        /// The iPhone has the request. It shows the paywall the next time that Maru is in front.
        case sent
        /// The request did not reach the iPhone.
        case notSent
    }

    /// The last list that the iPhone sent. The system keeps it between launches.
    private(set) var day: WatchDay?
    private(set) var proRequest: ProRequest?
    private(set) var notice: Notice?
    /// The doses with a request that runs. A second request for one of them does nothing.
    private(set) var inFlight: Set<OccurrenceID> = []
    /// Counts the records that the iPhone confirmed, for the success haptic.
    private(set) var confirmedCount = 0
    /// The request of each dose that got no reply. The same choice on the same row goes again with the same
    /// intent ID, so the iPhone applies it one time (T18).
    private var unanswered: [OccurrenceID: (action: IntakeAction, revision: IntakeEventID?, intent: IntakeEventID)] = [:]
    private let link = PhoneLink()

    init() {
        link.activate()
        Task { [weak self, days = link.days] in
            for await day in days {
                self?.show(day)
            }
        }
    }

    /// Asks the iPhone for the list of now. With no reply, the last list stays.
    func refresh() {
        link.refresh()
    }

    /// Asks the iPhone to show Maru Pro. The Watch sells nothing (D111).
    func showProOnPhone() {
        guard proRequest != .sending else { return }
        proRequest = .sending
        Task {
            if case .reply = await link.send(.showPro) {
                proRequest = .sent
            } else {
                proRequest = .notSent
            }
        }
    }

    func record(_ dose: WatchDay.Dose, as action: IntakeAction) {
        guard inFlight.insert(dose.id).inserted else { return }
        notice = nil
        let intent = unanswered[dose.id].flatMap { $0.action == action && $0.revision == dose.revision ? $0.intent : nil }
            ?? IntakeEventID()
        // The list that the user saw, before a new list can come in during the task (D123).
        let listedAt = day?.sentAt ?? .distantPast
        Task {
            let answer = await link.send(.record(
                dose.id, scheduleVersionID: dose.scheduleVersionID, action: action,
                revision: dose.revision, intent: intent, listedAt: listedAt
            ))
            inFlight.remove(dose.id)
            switch answer {
            case let .reply(reply):
                unanswered[dose.id] = nil
                if let day = reply.day { show(day) }
                switch reply.outcome {
                case .recorded: confirmedCount += 1
                case .changed: notice = .changed
                case .notRecorded: notice = reply.day == nil ? .locked : .notRecorded
                }
            case .notReachable:
                notice = .notReachable
            case .noAnswer:
                unanswered[dose.id] = (action, dose.revision, intent)
                notice = .notConfirmed
                // The next list tells what the iPhone has.
                link.refresh()
            }
        }
    }

    /// An application context can come after a newer reply. The newest list stays.
    private func show(_ day: WatchDay) {
        guard day.sentAt >= self.day?.sentAt ?? .distantPast else { return }
        // The locked screen replaces the list, so a notice about a dose does not stay for a later Pro list.
        if !day.isPro { notice = nil }
        if day.isPro != self.day?.isPro { proRequest = nil }
        self.day = day
    }
}
