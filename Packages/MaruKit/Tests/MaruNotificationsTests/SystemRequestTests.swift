import Foundation
import MaruCore
import Testing
import UserNotifications
@testable import MaruNotifications

@Suite("System notification requests (spec 8.1, 8.2, 8.3)")
struct SystemRequestTests {
    @Test func requestRepeatsOnItsCalendarTimeAndNamesTheItems() throws {
        let item = try Item(category: .medication, name: "Metformin", form: .tablet, color: .blue)
        var schedule = Schedule(itemID: item.id, isEnabled: true)
        let slotID = try schedule.addSlot().id
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: LocalDate(year: 2026, month: 1, day: 1),
                weeklyRule: WeeklyRule(weekdays: [.monday]),
                slotTimes: [SlotTime(slotID: slotID, time: WallClockTime(hour: 8, minute: 0))],
                dose: Dose("500 mg"),
                timeZonePolicy: .fixed(NamedTimeZone(identifier: "America/New_York"))
            )
        )
        let now = try Date("2026-03-02T00:00:00Z", strategy: .iso8601)
        let plan = ReminderPlan(items: [item], schedules: [schedule], now: now, deviceTimeZone: .utc)
        let request = try #require(plan.requests.first)

        let locale = Locale(identifier: "en_US")
        let system = UNNotificationRequest(request, locale: locale)

        // The reminder says what to take, and never that a dose is not taken (spec 8.2, D029).
        #expect(system.content.title == "Time to take")
        #expect(system.content.body == "Metformin")
        #expect(system.content.subtitle.isEmpty)
        // One item at the time, so the request has the category of the "Taken" action (D034), and the time-sensitive level (D062).
        #expect(system.content.categoryIdentifier == ReminderCategory.single.rawValue)
        #expect(system.content.interruptionLevel == .timeSensitive)
        // Every category that a request can have has its own actions in the one registry (D090).
        #expect(ReminderCategory.allCases.map { ReminderAction.category($0, locale: locale).actions.map(\.identifier) } == [
            ["reminder.taken", "reminder.skip", "reminder.snooze"],
            ["reminder.taken", "reminder.skip", "reminder.snooze"],
            ["reminder.snooze"],
        ])
        #expect(ReminderAction.category(.group, locale: locale).actions.map(\.title) == ["Take All", "Skip All", "Remind in 10 min"])
        // With the names off, the text names no item.
        let neutral = ReminderContent(kind: .due, names: nil).text(locale: locale)
        #expect(neutral == ReminderText(title: "Time to take", body: "Open Maru to see your plan."))
        // A long list names two items and the count of the others.
        let long = ReminderContent(kind: .again, names: ["A", "B", "C", "D"]).text(locale: locale)
        #expect(long == ReminderText(title: "No record yet", body: "A, B, and 2 more"))
        // The system fires it at 08:00 in New York on each Monday. The calendar counts from Sunday = 1.
        let trigger = try #require(system.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        var monday = DateComponents()
        monday.timeZone = TimeZone(identifier: "America/New_York")
        monday.hour = 8
        monday.minute = 0
        monday.weekday = 2
        #expect(trigger.dateComponents == monday)
        // The pending request reads back as the request that the engine wants, so a second run adds nothing.
        #expect(
            PendingReminder(system)
                == PendingReminder(
                    identifier: request.identifier,
                    userInfo: request.userInfo,
                    text: request.content.text(locale: locale),
                    presentation: ReminderPresentation(category: .single)
                )
        )
    }
}
