import Foundation

/// A message between the iPhone app and the Watch app (D071).
///
/// The iPhone database is the only store. The Watch shows a list that the iPhone sent, and it asks the iPhone
/// for each record. A message that does not decode gives `nil`, so a Watch app and an iPhone app of different
/// versions record nothing and show no success.
public protocol WatchMessage: Codable, Sendable {}

extension WatchMessage {
    public init?(message: Data) {
        guard let value = try? PropertyListDecoder().decode(Self.self, from: message) else { return nil }
        self = value
    }

    public var message: Data? {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try? encoder.encode(self)
    }
}

/// The doses of today, as the iPhone sends them to the Watch. It has no as-needed item.
///
/// The Watch app is a Pro feature (D111). A list for a free user has no dose, so no health data leaves the iPhone.
public struct WatchDay: WatchMessage, Equatable {
    public struct Dose: Codable, Equatable, Identifiable, Sendable {
        public let id: OccurrenceID
        /// The schedule version that the occurrence had in the list. A record request sends it back.
        public let scheduleVersionID: ScheduleVersionID
        /// The name of the item. With two or more active members of the Family, the iPhone writes the owner into it, for example
        /// "Mom: Levothyroxine", so two rows with one item name stay apart on the Watch (D123).
        public let name: String
        public let amount: String?
        public let status: OccurrenceStatus
        /// The last event of the record that the row shows, or `nil` for a record with no event.
        /// A record request sends it back, so a row that is not current records nothing.
        public let revision: IntakeEventID?
        /// The intake time of a taken dose. For each other dose, the planned time.
        public let time: Date

        public init(
            id: OccurrenceID, scheduleVersionID: ScheduleVersionID, name: String, amount: String?,
            status: OccurrenceStatus, revision: IntakeEventID?, time: Date
        ) {
            self.id = id
            self.scheduleVersionID = scheduleVersionID
            self.name = name
            self.amount = amount
            self.status = status
            self.revision = revision
            self.time = time
        }
    }

    public struct Slot: Codable, Equatable, Identifiable, Sendable {
        public let part: DayPart
        public let doses: [Dose]

        public var id: DayPart { part }

        public init(part: DayPart, doses: [Dose]) {
            self.part = part
            self.doses = doses
        }
    }

    /// The key of the list in the application context of WatchConnectivity.
    public static let contextKey = "day"

    /// When the iPhone made the list. The Watch shows it, and it keeps the newest list.
    public let sentAt: Date
    /// The time after which the list is not of today any more.
    public let expiresAt: Date
    /// The app tint (D025). It is no health data.
    public let tint: ItemColor
    /// Maru Pro is active on the iPhone (D107). When it is `false`, the Watch shows the locked screen, and `slots` is empty.
    public let isPro: Bool
    public let slots: [Slot]

    public init(sentAt: Date, expiresAt: Date, tint: ItemColor, isPro: Bool, slots: [Slot]) {
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.tint = tint
        self.isPro = isPro
        self.slots = isPro ? slots : []
    }

    /// `false` for a list of an earlier day. The Watch must not show it as today (spec 9).
    public func isCurrent(at now: Date) -> Bool {
        now < expiresAt
    }
}

/// What the Watch asks the iPhone for.
public enum WatchRequest: WatchMessage, Equatable {
    /// The list of today.
    case today
    /// One record for a dose of the list. The IDs carry no health data.
    /// - `revision`: The revision of the row that the user saw.
    /// - `intent`: The ID of this choice of the user. It becomes the ID of the event, and the same request
    ///   again keeps it, so the iPhone applies one choice one time (T18).
    /// - `listedAt`: `WatchDay.sentAt` of the list that the user saw. The iPhone records nothing for an item whose owner changed
    ///   after it (D123).
    case record(
        OccurrenceID, scheduleVersionID: ScheduleVersionID, action: IntakeAction,
        revision: IntakeEventID?, intent: IntakeEventID, listedAt: Date
    )
    /// A free user tapped "Show on iPhone" on the locked screen (D111). The iPhone shows the paywall the next time
    /// that Maru is in front. The Watch sells nothing.
    case showPro
}

/// What a record request of the Watch does to the stored record.
public enum WatchStep: Equatable, Sendable {
    /// The record is the one that the Watch showed. The iPhone writes the event.
    case write
    /// The event of this intent is the current end of the record. Nothing to write, and the answer is "recorded".
    case applied
    /// The record is not the one that the Watch showed, or a later choice came after this intent.
    /// The iPhone writes nothing.
    case changed
}

extension OccurrenceRecord {
    public func watchStep(intent: IntakeEventID, revision: IntakeEventID?) -> WatchStep {
        if events.last?.id == intent { return .applied }
        if events.contains(where: { $0.id == intent }) || events.last?.id != revision { return .changed }
        return .write
    }
}

/// The answer of the iPhone to each request.
public struct WatchReply: WatchMessage, Equatable {
    public enum Outcome: String, Codable, Sendable {
        /// The record transaction of the request committed on the iPhone (spec 7.2).
        /// The Watch shows a success for no other value.
        case recorded
        /// The dose is not the one that the Watch showed. Nothing was written.
        case changed
        /// Nothing was written for another reason, or the request asked for no record.
        case notRecorded
    }

    public let outcome: Outcome
    /// The list after the request, or `nil` when the iPhone cannot read it, for example after a restart and before the first unlock.
    public let day: WatchDay?

    public init(outcome: Outcome, day: WatchDay?) {
        self.outcome = outcome
        self.day = day
    }
}
