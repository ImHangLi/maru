import Foundation
@testable import MaruCore

enum Fixtures {
    static func date(_ year: Int, _ month: Int, _ day: Int) -> LocalDate {
        try! LocalDate(year: year, month: month, day: day)
    }

    static func time(_ hour: Int, _ minute: Int = 0) -> WallClockTime {
        try! WallClockTime(hour: hour, minute: minute)
    }

    static let shanghai = try! NamedTimeZone(identifier: "Asia/Shanghai")
    static let newYork = try! NamedTimeZone(identifier: "America/New_York")

    /// An instant from ISO 8601 text, for example `2026-03-01T04:00:00Z`.
    static func instant(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }

    static func item(
        category: ItemCategory = .supplement, name: String = "Vitamin D", followUp: FollowUpSetting? = nil,
        followUpChanged: Date? = nil, alarm: Bool = false
    ) -> Item {
        try! Item(
            category: category, name: name, form: .capsule, color: .pink,
            followUp: followUp, followUpChanged: followUpChanged, alarm: alarm
        )
    }

    /// The text of a test notification center: the kind, then the names, so a test sees each change of the text.
    static func text(for content: ReminderContent) -> ReminderText {
        ReminderText(title: "\(content.kind)", body: content.names?.joined(separator: ", ") ?? "")
    }

    /// A schedule with morning and evening slots and a first version, effective on 2026-01-01.
    static func twiceDailySchedule(
        dose: Dose? = nil
    ) -> (schedule: Schedule, morning: ScheduleSlotID, evening: ScheduleSlotID) {
        var schedule = Schedule(itemID: item().id, isEnabled: true)
        let morning = try! schedule.addSlot().id
        let evening = try! schedule.addSlot().id
        let version = try! ScheduleVersion(
            scheduleID: schedule.id,
            effectiveFrom: date(2026, 1, 1),
            weeklyRule: .everyDay,
            slotTimes: [SlotTime(slotID: morning, time: time(8)), SlotTime(slotID: evening, time: time(20))],
            dose: dose,
            timeZonePolicy: .fixed(shanghai)
        )
        try! schedule.appendVersion(version)
        return (schedule, morning, evening)
    }

    /// A day cycle from a date. With no counts, it is every other day.
    static func cycle(from start: LocalDate, on daysOn: Int = 1, off daysOff: Int = 1) -> DayCycle {
        try! DayCycle(start: start, daysOn: daysOn, daysOff: daysOff)
    }

    /// An enabled schedule with one slot for each time and a first version, effective on 2026-01-01.
    static func schedule(
        itemID: ItemID,
        times: [WallClockTime],
        weeklyRule: WeeklyRule = .everyDay,
        dayCycle: DayCycle? = nil,
        timeZonePolicy: TimeZonePolicy = .fixed(shanghai)
    ) -> Schedule {
        var schedule = Schedule(itemID: itemID, isEnabled: true)
        let slotTimes = times.map { SlotTime(slotID: try! schedule.addSlot().id, time: $0) }
        let version = try! ScheduleVersion(
            scheduleID: schedule.id,
            effectiveFrom: date(2026, 1, 1),
            weeklyRule: weeklyRule,
            dayCycle: dayCycle,
            slotTimes: slotTimes,
            timeZonePolicy: timeZonePolicy
        )
        try! schedule.appendVersion(version)
        return schedule
    }

    static func occurrence(slotID: ScheduleSlotID = ScheduleSlotID(), on day: LocalDate = date(2026, 3, 1)) -> Occurrence {
        Occurrence(
            slotID: slotID,
            plannedDate: day,
            plannedTime: time(8),
            timeZone: shanghai,
            scheduleVersionID: ScheduleVersionID()
        )
    }

    static func event(
        for occurrence: Occurrence,
        _ action: IntakeAction,
        supersedes: IntakeEventID? = nil
    ) -> IntakeEvent {
        IntakeEvent(
            occurrenceID: occurrence.id,
            action: action,
            occurredAt: Date(timeIntervalSince1970: 1_000),
            recordedAt: Date(timeIntervalSince1970: 1_001),
            source: .app,
            supersedes: supersedes
        )
    }
}
