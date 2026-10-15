import Foundation

/// One dose of an as-needed item (D021). The user records it at any time, and each record makes its own
/// occurrence at the record instant. It has no slot, no schedule version, and no reminder.
///
/// It shares the ID space and the event history of `Occurrence`, so `OccurrenceRecord` applies the same rules
/// to its events: one valid state, and an undo or a correction as a revision (spec 7.2).
public struct AsNeededOccurrence: Hashable, Sendable {
    public let id: OccurrenceID
    public let itemID: ItemID
    /// The date of the record instant in `timeZone`.
    public let plannedDate: LocalDate
    /// The clock time of the record instant in `timeZone`, to the minute. The intake event keeps the exact instant.
    public let plannedTime: WallClockTime
    public let timeZone: NamedTimeZone
    /// The amount of this dose as the user wrote it, copied from the item when the dose was recorded (D091).
    /// `nil` means no amount.
    public let dose: Dose?

    public init(
        id: OccurrenceID,
        itemID: ItemID,
        plannedDate: LocalDate,
        plannedTime: WallClockTime,
        timeZone: NamedTimeZone,
        dose: Dose? = nil
    ) {
        self.id = id
        self.itemID = itemID
        self.plannedDate = plannedDate
        self.plannedTime = plannedTime
        self.timeZone = timeZone
        self.dose = dose
    }

    /// The occurrence of a dose that the user records at `instant`, in the time zone of the device.
    public init(
        id: OccurrenceID = OccurrenceID(), itemID: ItemID, at instant: Date, in timeZone: NamedTimeZone, dose: Dose? = nil
    ) {
        self.init(
            id: id,
            itemID: itemID,
            plannedDate: LocalDate(instant, in: timeZone),
            plannedTime: WallClockTime(instant, in: timeZone),
            timeZone: timeZone,
            dose: dose
        )
    }
}

extension Schedule {
    /// A schedule is active on a date when a version is in force on it and the schedule has not ended.
    /// `isEnabled` turns off the reminders only, so the item still has its slots (T07).
    public func isActive(on date: LocalDate) -> Bool {
        guard version(on: date) != nil else { return false }
        return endDate.map { date <= $0 } ?? true
    }
}

extension Item {
    /// An item is as needed on a date when it is not archived and no schedule of the item is active (D021).
    public func isAsNeeded(on date: LocalDate, schedules: some Sequence<Schedule>) -> Bool {
        !isArchived && !schedules.contains { $0.itemID == id && $0.isActive(on: date) }
    }
}
