import Foundation

/// A message between the iPhone app and the Watch app (D065).
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
public struct WatchDay: WatchMessage, Equatable {
    public struct Dose: Codable, Equatable, Identifiable, Sendable {
        public let id: OccurrenceID
        /// The schedule version that the occurrence had in the list. A record request sends it back.
        public let scheduleVersionID: ScheduleVersionID
        public let name: String
        public let amount: String?
        public let status: OccurrenceStatus
        /// The intake time of a taken dose. For each other dose, the planned time.
        public let time: Date

        public init(
            id: OccurrenceID, scheduleVersionID: ScheduleVersionID, name: String, amount: String?,
            status: OccurrenceStatus, time: Date
        ) {
            self.id = id
            self.scheduleVersionID = scheduleVersionID
            self.name = name
            self.amount = amount
            self.status = status
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
    public let slots: [Slot]

    public init(sentAt: Date, expiresAt: Date, tint: ItemColor, slots: [Slot]) {
        self.sentAt = sentAt
        self.expiresAt = expiresAt
        self.tint = tint
        self.slots = slots
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
    case record(OccurrenceID, scheduleVersionID: ScheduleVersionID, action: IntakeAction)
}

/// The answer of the iPhone to each request.
public struct WatchReply: WatchMessage, Equatable {
    /// `true` only after the record transaction of the request committed on the iPhone (spec 7.2).
    /// The Watch shows a success for no other value.
    public let recorded: Bool
    /// The list after the request, or `nil` when the iPhone cannot read it, for example while it is locked.
    public let day: WatchDay?

    public init(recorded: Bool, day: WatchDay?) {
        self.recorded = recorded
        self.day = day
    }
}
