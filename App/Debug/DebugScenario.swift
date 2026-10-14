#if DEBUG
import Foundation
import MaruCore
import MaruDatabase

/// The test-data scenarios of spec 14 A. A debug build only. Items and doses are made up.
///
/// The raw value is the value of `-MaruScenario`, for example `-MaruScenario twoSlots`.
enum DebugScenario: String, CaseIterable, Identifiable {
    case twoSlots
    case expiredTap
    case crossDayTap
    case notificationsDenied
    case failedWrite
    case sevenDaysAway
    case versionUpdate
    case asNeeded
    case fixedZone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twoSlots: "Two times a day"
        case .expiredTap: "Expired reminder tap"
        case .crossDayTap: "Cross-day reminder tap"
        case .notificationsDenied: "Notifications denied"
        case .failedWrite: "Failed write"
        case .sevenDaysAway: "Seven days with no records"
        case .versionUpdate: "Version update"
        case .asNeeded: "As-needed item"
        case .fixedZone: "Medication in another time zone"
        }
    }

    var summary: String {
        switch self {
        case .twoSlots: "One item at 08:00 and 20:00, one item at 08:00."
        case .expiredTap: "Taps the 08:00 reminder of two days ago."
        case .crossDayTap: "Taps the 23:30 reminder of yesterday, after midnight."
        case .notificationsDenied: "Steps only. It loads no test data and changes no setting."
        case .failedWrite: "The next record commits, then reports “unavailable”."
        case .sevenDaysAway: "Two items planned for eight days, no record."
        case .versionUpdate: "08:00 until yesterday, 09:00 from today. Yesterday is recorded."
        case .asNeeded: "One as-needed item and one daily item."
        case .fixedZone: "A medication at 08:00 in \(Self.otherZone.identifier)."
        }
    }

    /// What to check after the load.
    var checks: [String] {
        switch self {
        case .twoSlots:
            [
                "Today shows a Morning card with two items and an Evening card with one.",
                "Record the Morning card. The Evening card stays open.",
                "With notifications on, iPhone has two daily reminders: 08:00 and 20:00.",
            ]
        case .expiredTap:
            [
                "Today opens with no sheet and no focus on a row.",
                "Nothing is recorded. Today’s 08:00 stays open (T15, D081).",
            ]
        case .crossDayTap:
            [
                "Today opens with no sheet. The tap does not record today (T15, D081).",
                "Today’s 23:30 stays open. Record yesterday’s dose from History.",
            ]
        case .notificationsDenied:
            [
                "This check uses your real list. The setting is for the whole app, so your real reminders stop while it is off.",
                "Open the Settings app > Maru > Notifications, and turn Allow Notifications off.",
                "Back in Maru, Today shows “Notifications are off”. Settings shows Off and Open Settings (T13, T14).",
                "You can still record. No system prompt shows again.",
                "Then turn Allow Notifications on again. Back in Maru, Settings shows On, and your reminders are set again.",
            ]
        case .failedWrite:
            [
                "Record any item. A “Not Saved” alert offers Try Again. After Cancel, the row and the banner at the top offer it too (D014, T19).",
                "No success haptic and no “recorded” state before the retry.",
                "Try Again on the row or the banner succeeds. The item has one record, not two (T18).",
            ]
        case .sevenDaysAway:
            [
                "Today shows only today. No backlog of missed days, no streak, no blame (spec 4).",
                "Tap History on Today. History shows the past days with no record, with no streak and no bulk fill (D021).",
                "Follow-ups stop after seven days away. Daily reminders continue (D021).",
            ]
        case .versionUpdate:
            [
                "Today shows Demo Calcium at 09:00 with 2 tablets.",
                "Tap History on Today. In History, yesterday shows Demo Calcium in the Morning, taken at 8:05. The move to 09:00 does not change it.",
                "With notifications on, the only daily reminder of the item is 09:00.",
            ]
        case .asNeeded:
            [
                "Today ends with an As Needed card for Demo Antacid.",
                "Record it two times. Each record is its own dose with its own time (D021).",
                "The item has no reminder.",
            ]
        case .fixedZone:
            [
                "Demo Medication keeps 08:00 in \(Self.otherZone.identifier), not 08:00 on this iPhone (spec 8.5).",
                "Today shows it at the time of this iPhone that matches 08:00 there.",
                "Change the device time zone. The item keeps its zone, and supplements move.",
            ]
        }
    }

    /// `false` for a scenario that only lists steps. It changes no store and no system setting.
    var loadsData: Bool { self != .notificationsDenied }

    /// A time zone that is not the zone of the device.
    static var otherZone: NamedTimeZone {
        let identifier = TimeZone.current.identifier == "Asia/Tokyo" ? "Europe/London" : "Asia/Tokyo"
        return (try? NamedTimeZone(identifier: identifier)) ?? .utc
    }
}

extension AppStore {
    /// A clear that did not end by its deadline can still remove a request of the launch reconcile later.
    /// One more full run, a `clearWait` after the first run, sets the reminders again.
    func reconcileAfterLateClear() async {
        guard let clear = debug.notificationClear else { return }
        debug.notificationClear = nil
        guard await !clear.value else { return }
        try? await Task.sleep(for: DebugStore.clearWait)
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        _ = try? await reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
    }

    /// Writes the scenario of this launch into the new, empty debug store, one time, before the first read.
    /// `DebugStore.launch` selected the debug store already, so the real database is not opened.
    /// - Returns: A problem for the debug notice, when the seed failed.
    func seedLaunchScenario(at now: Date, deviceTimeZone: NamedTimeZone) async -> String? {
        guard let scenario = DebugStore.launch.seed, !debug.didSeed else { return nil }
        debug.didSeed = true
        do {
            debug.launchTap = try await seed(scenario, at: now, deviceTimeZone: deviceTimeZone)
            return nil
        } catch {
            return "The scenario did not load completely: \(error)"
        }
    }

    /// - Returns: The reminder tap of the scenario, if it has one.
    private func seed(
        _ scenario: DebugScenario,
        at now: Date,
        deviceTimeZone: NamedTimeZone
    ) async throws -> DeliveredReminder? {
        let store = try open()
        let today = LocalDate(now, in: deviceTimeZone)
        var tap: DeliveredReminder?
        switch scenario {
        case .twoSlots:
            try await add(store, "Demo Vitamin A", .tablet, .orange, [(8, 0), (20, 0)], "1 tablet", from: today)
            try await add(store, "Demo Fish Oil", .softgel, .yellow, [(8, 0)], "2 softgels", from: today)
        case .expiredTap:
            try await add(store, "Demo Vitamin B", .tablet, .green, [(8, 0)], "1 tablet", from: today.adding(days: -3))
            tap = try await reminder(store, at: (8, 0), on: today.adding(days: -2), now: now, deviceTimeZone: deviceTimeZone)
        case .crossDayTap:
            try await add(store, "Demo Magnesium", .capsule, .purple, [(23, 30)], "2 capsules", from: today.adding(days: -2))
            tap = try await reminder(store, at: (23, 30), on: today.adding(days: -1), now: now, deviceTimeZone: deviceTimeZone)
        case .notificationsDenied:
            break
        case .failedWrite:
            try await add(store, "Demo Vitamin C", .tablet, .orange, [(8, 0), (20, 0)], "1 tablet", from: today)
            debug.failsNextRecord = true
        case .sevenDaysAway:
            try await add(store, "Demo Iron", .tablet, .brown, [(8, 0)], "1 tablet", from: today.adding(days: -8))
            try await add(store, "Demo Vitamin D", .drop, .yellow, [(21, 0)], nil, from: today.adding(days: -8))
        case .versionUpdate:
            try await versionUpdate(store, today: today, now: now, deviceTimeZone: deviceTimeZone)
        case .asNeeded:
            let item = try Item(category: .medication, name: "Demo Antacid", form: .tablet, color: .mint)
            try await store.save(item)
            try await add(store, "Demo Vitamin E", .softgel, .pink, [(8, 0)], nil, from: today)
        case .fixedZone:
            try await add(
                store, "Demo Medication", .tablet, .blue, [(8, 0)], "1 tablet", from: today,
                category: .medication, policy: .fixed(DebugScenario.otherZone)
            )
            try await add(store, "Demo Vitamin K", .capsule, .green, [(8, 0)], nil, from: today)
        }
        _ = try await store.generate(at: now, deviceTimeZone: deviceTimeZone)
        return tap
    }

    @discardableResult
    private func add(
        _ store: LocalStore,
        _ name: String,
        _ form: ItemForm,
        _ color: ItemColor,
        _ times: [(hour: Int, minute: Int)],
        _ amount: String?,
        from date: LocalDate,
        category: ItemCategory = .supplement,
        policy: TimeZonePolicy = .followsDevice
    ) async throws -> Schedule {
        let item = try Item(category: category, name: name, form: form, color: color)
        var schedule = Schedule(itemID: item.id, isEnabled: true)
        let slotTimes = try times.map { time in
            SlotTime(slotID: try schedule.addSlot().id, time: try WallClockTime(hour: time.hour, minute: time.minute))
        }
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: date,
                weeklyRule: .everyDay,
                slotTimes: slotTimes,
                dose: amount.flatMap(Dose.init),
                timeZonePolicy: policy
            )
        )
        try await store.save(item, schedule: schedule)
        return schedule
    }

    /// 08:00 with 1 tablet from three days ago, and yesterday taken. Then a new version: 09:00 with 2 tablets
    /// from today. The generation of today moves today's open occurrence to the new version (D019).
    private func versionUpdate(_ store: LocalStore, today: LocalDate, now: Date, deviceTimeZone: NamedTimeZone) async throws {
        var schedule = try await add(
            store, "Demo Calcium", .tablet, .pink, [(8, 0)], "1 tablet", from: today.adding(days: -3)
        )
        let yesterday = today.adding(days: -1)
        let occurrences = try await store.generateOccurrences(at: now, deviceTimeZone: deviceTimeZone)
        if let occurrence = occurrences.first(where: { $0.plannedDate == yesterday }) {
            let takenAt = deviceTimeZone.resolve(try WallClockTime(hour: 8, minute: 5), on: yesterday).earliestInstant
            let event = IntakeEvent(
                occurrenceID: occurrence.id, action: .taken, occurredAt: takenAt, recordedAt: takenAt, source: .app
            )
            try await store.record([(event, occurrence.scheduleVersionID)])
        }
        guard let slot = schedule.slots.first else { return }
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: today,
                weeklyRule: .everyDay,
                slotTimes: [SlotTime(slotID: slot.id, time: try WallClockTime(hour: 9, minute: 0))],
                dose: Dose("2 tablets"),
                timeZonePolicy: .followsDevice
            )
        )
        try await store.save(schedule)
    }

    /// The series reminder of `time` as the system would deliver it on `date`, on time.
    private func reminder(
        _ store: LocalStore,
        at time: (hour: Int, minute: Int),
        on date: LocalDate,
        now: Date,
        deviceTimeZone: NamedTimeZone
    ) async throws -> DeliveredReminder? {
        let time = try WallClockTime(hour: time.hour, minute: time.minute)
        // Only the `userInfo` matters here. Neutral text keeps one daily request for a series of every day (D029).
        let plan = try await store.reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: .hideNames)
        guard let request = plan.requests.first(where: { $0.trigger.time == time && $0.trigger.weekday == nil }) else {
            return nil
        }
        return DeliveredReminder(
            deliveredAt: deviceTimeZone.resolve(time, on: date).earliestInstant,
            userInfo: request.userInfo,
            triggerWeekday: nil
        )
    }
}
#endif
