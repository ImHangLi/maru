/// The rule that a stored row broke when it did not load (D088). The raw values are fixed words, so a log line and an
/// analytics event can name the rule and nothing else. A value never holds a name, a dose, a time, or an ID.
public enum StoredDataRule: String, CaseIterable, Hashable, Sendable {
    case itemRow = "item_row"
    case itemFollowUp = "item_follow_up"
    case itemNote = "item_note"
    case scheduleRow = "schedule_row"
    case scheduleSlot = "schedule_slot"
    case versionRow = "version_row"
    case versionDose = "version_dose"
    case versionZone = "version_zone"
    case versionCycle = "version_cycle"
    /// A version starts before the version before it (`ScheduleError.versionBeforeLatest`).
    case versionOrder = "version_order"
    /// A version names a slot that its schedule does not have (`ScheduleError.unknownSlot`).
    case versionUnknownSlot = "version_unknown_slot"
    /// `ScheduleError.noSlotTimes`, `duplicateSlot`, `weekdaysWithDayCycle`, `invalidDayCycle`, `conflictingVersion`,
    /// `foreignVersion`, or `noVersion`.
    case versionRule = "version_rule"
    /// An occurrence row that the reminder plans read, for example the slot of a closed dose.
    case occurrenceRow = "occurrence_row"
    case other

    /// The rule for a domain error that the schedule or the item rejected.
    public init(domainError error: any Error) {
        switch error {
        case ScheduleError.versionBeforeLatest: self = .versionOrder
        case ScheduleError.unknownSlot: self = .versionUnknownSlot
        case is ScheduleError: self = .versionRule
        case is ItemError: self = .itemRow
        default: self = .other
        }
    }
}
