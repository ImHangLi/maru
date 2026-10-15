import Foundation

public enum RecordError: Error, Equatable, Sendable {
    /// The event belongs to another occurrence.
    case wrongOccurrence
    /// The occurrence already has a valid state, and the event does not revise it.
    case alreadyRecorded
    /// The event revises an event that is not the current one.
    case staleRevision
    /// The event ID exists with different content.
    case conflictingEvent
    /// An undo needs a current taken or skipped event.
    case nothingToUndo
}

/// The natural key of an occurrence. The database enforces one occurrence per key (T17).
public struct OccurrenceKey: Hashable, Sendable {
    public let slotID: ScheduleSlotID
    public let plannedDate: LocalDate

    public init(slotID: ScheduleSlotID, plannedDate: LocalDate) {
        self.slotID = slotID
        self.plannedDate = plannedDate
    }
}

/// One planned intake: one slot on one logical date. It snapshots the plan so later edits do not rewrite it.
/// The snapshot follows the schedule only while the occurrence has no intake event and its date is not
/// in the past. See `OccurrenceGeneration`.
public struct Occurrence: Hashable, Sendable {
    public let id: OccurrenceID
    public let slotID: ScheduleSlotID
    /// The logical plan date. Today and yesterday stay separate.
    public let plannedDate: LocalDate
    public let plannedTime: WallClockTime
    public let timeZone: NamedTimeZone
    public let scheduleVersionID: ScheduleVersionID

    public var key: OccurrenceKey {
        OccurrenceKey(slotID: slotID, plannedDate: plannedDate)
    }

    public init(
        id: OccurrenceID = OccurrenceID(),
        slotID: ScheduleSlotID,
        plannedDate: LocalDate,
        plannedTime: WallClockTime,
        timeZone: NamedTimeZone,
        scheduleVersionID: ScheduleVersionID
    ) {
        self.id = id
        self.slotID = slotID
        self.plannedDate = plannedDate
        self.plannedTime = plannedTime
        self.timeZone = timeZone
        self.scheduleVersionID = scheduleVersionID
    }
}

/// What the user chose. "Snooze" is not an intake action (spec 7.2).
public enum IntakeAction: String, Hashable, Sendable, Codable {
    case taken
    case skipped
    /// Takes back the current event. The occurrence is unrecorded again, and the history stays (T20).
    case undo
}

public enum EventSource: String, Hashable, Sendable {
    case app
    case notificationAction
}

/// An append-only record of one user choice about one occurrence.
public struct IntakeEvent: Hashable, Sendable {
    public let id: IntakeEventID
    public let occurrenceID: OccurrenceID
    public let action: IntakeAction
    /// When the user says the intake happened.
    public let occurredAt: Date
    /// When the app wrote the event.
    public let recordedAt: Date
    public let source: EventSource
    /// The event that this one revises. `nil` only for the first event of an occurrence.
    public let supersedes: IntakeEventID?

    public init(
        id: IntakeEventID = IntakeEventID(),
        occurrenceID: OccurrenceID,
        action: IntakeAction,
        occurredAt: Date,
        recordedAt: Date,
        source: EventSource,
        supersedes: IntakeEventID? = nil
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.action = action
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.source = source
        self.supersedes = supersedes
    }
}

public enum OccurrenceStatus: String, Hashable, Sendable, Codable {
    case unrecorded
    case taken
    case skipped
}

/// The event history of one occurrence. The history is one linear chain of revisions, so the occurrence
/// has exactly one valid state at any time. Two intakes can never both count (spec 7.2, T18).
public struct OccurrenceRecord: Hashable, Sendable {
    public let occurrenceID: OccurrenceID
    public private(set) var events: [IntakeEvent] = []

    public init(occurrenceID: OccurrenceID) {
        self.occurrenceID = occurrenceID
    }

    /// The one valid event, or `nil` when nothing is recorded or the last event is an undo.
    public var currentEvent: IntakeEvent? {
        guard let last = events.last, last.action != .undo else { return nil }
        return last
    }

    public var status: OccurrenceStatus {
        switch currentEvent?.action {
        case nil, .undo: .unrecorded
        case .taken: .taken
        case .skipped: .skipped
        }
    }

    /// Appends an event. Sending the same event again changes nothing, so a double tap is safe.
    public mutating func record(_ event: IntakeEvent) throws {
        guard event.occurrenceID == occurrenceID else { throw RecordError.wrongOccurrence }
        if let existing = events.first(where: { $0.id == event.id }) {
            guard existing == event else { throw RecordError.conflictingEvent }
            return
        }
        // The chain is linear: every event after the first revises the last event, even after an undo.
        switch (events.last, event.supersedes) {
        case (nil, nil):
            guard event.action != .undo else { throw RecordError.nothingToUndo }
        case (nil, .some):
            throw RecordError.staleRevision
        case (.some, nil):
            throw RecordError.alreadyRecorded
        case let (.some(last), .some(target)):
            guard target == last.id else { throw RecordError.staleRevision }
            guard event.action != .undo || last.action != .undo else { throw RecordError.nothingToUndo }
        }
        events.append(event)
    }
}

extension OccurrenceRecord {
    /// The one place that makes the next event of a record (D090). The event revises the last event of the record, also after
    /// an undo, so a second event from a stale read is rejected (T18).
    ///
    /// - Parameters:
    ///   - now: When the app writes the event.
    ///   - occurredAt: When the user says that the intake happened. `nil` means `now`.
    public func nextEvent(_ action: IntakeAction, at now: Date, occurredAt: Date? = nil, source: EventSource) -> IntakeEvent {
        IntakeEvent(
            occurrenceID: occurrenceID,
            action: action,
            occurredAt: occurredAt ?? now,
            recordedAt: now,
            source: source,
            supersedes: events.last?.id
        )
    }
}
