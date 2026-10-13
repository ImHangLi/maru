import Foundation

/// A stable, type-safe identifier. The `Tag` type only keeps different kinds of IDs apart at compile time.
public struct Identifier<Tag>: Hashable, Sendable, Codable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public typealias ItemID = Identifier<Item>
public typealias ScheduleID = Identifier<Schedule>
public typealias ScheduleSlotID = Identifier<ScheduleSlot>
public typealias ScheduleVersionID = Identifier<ScheduleVersion>
public typealias OccurrenceID = Identifier<Occurrence>
public typealias IntakeEventID = Identifier<IntakeEvent>
