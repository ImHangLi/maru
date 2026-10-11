#if DEBUG
import Foundation
import MaruCore
import MaruDatabase

/// Launch arguments of a debug build, for screenshots and manual checks. A release build does not have this code.
enum DebugLaunch {
    /// `-MaruSampleData YES`: load the sample items when the store has no item.
    /// `-MaruSampleData one` loads only the first sample, for a page with one card.
    static var wantsSampleData: Bool {
        UserDefaults.standard.bool(forKey: "MaruSampleData") || onlyOneSample
    }

    static var onlyOneSample: Bool {
        UserDefaults.standard.string(forKey: "MaruSampleData") == "one"
    }

    /// `-MaruSampleRecords YES`: with the sample items, record morning as taken, one noon item as taken,
    /// and one evening item as skipped, through the record transaction. For screenshots of recorded rows.
    static var wantsSampleRecords: Bool {
        UserDefaults.standard.bool(forKey: "MaruSampleRecords")
    }

    /// `-MaruSampleHistory YES`: the sample schedules start six days ago, and some past doses get records
    /// through the backfill transaction. For screenshots of the history.
    /// `-MaruSampleHistory 40` starts them that many days ago, for more than one page of days.
    static var wantsSampleHistory: Bool {
        sampleHistoryDays > 0
    }

    static var sampleHistoryDays: Int {
        let days = UserDefaults.standard.integer(forKey: "MaruSampleHistory")
        return days > 0 ? days : UserDefaults.standard.bool(forKey: "MaruSampleHistory") ? 6 : 0
    }

    /// `-MaruHistory open`: open the history after the first read. `correct` also opens the time of the
    /// first taken dose, `backfill` the time of the first dose with no record, and `older` scrolls to the
    /// oldest loaded day. The simulator cannot tap or scroll.
    static var history: String? {
        UserDefaults.standard.string(forKey: "MaruHistory")
    }

    @MainActor static var didOpenHistory = false
    @MainActor static var didShowHistoryDemo = false

    /// `-MaruTab myList`: start on My Items. A screenshot needs it, because a new session opens Today (spec 1).
    static var tab: AppTab? {
        UserDefaults.standard.string(forKey: "MaruTab") == "myList" ? .myList : nil
    }

    /// `-MaruTap 8:00` or `-MaruTap 8:00+120`: after the first read, act as a tap on the reminder of that time of today,
    /// delivered on time or that many minutes late. The simulator cannot set the delivery date of a notification.
    static var tap: (time: WallClockTime, delay: Int)? {
        guard let value = UserDefaults.standard.string(forKey: "MaruTap") else { return nil }
        let parts = value.split(separator: "+")
        let clock = parts[0].split(separator: ":").compactMap { Int($0) }
        guard clock.count == 2, let time = try? WallClockTime(hour: clock[0], minute: clock[1]) else { return nil }
        return (time, parts.count > 1 ? Int(parts[1]) ?? 0 : 0)
    }

    @MainActor static var didTap = false
    /// Today showed the reminder result of a debug reset.
    @MainActor static var didReportReset = false

    /// `-MaruScenario twoSlots`: at launch, load that debug scenario into a new debug store, as the debug menu does.
    /// The names are the raw values of `DebugScenario`. A tap scenario taps after the first read.
    static var scenario: DebugScenario? {
        UserDefaults.standard.string(forKey: "MaruScenario").flatMap(DebugScenario.init)
    }

    /// `-MaruSettings YES`: open the settings sheet at launch, for screenshots.
    /// `-MaruSettings ask`: also show the system notification prompt first, as a save with a reminder time does.
    /// `-MaruSettings debug`: also open the debug menu.
    static var settings: String? {
        UserDefaults.standard.string(forKey: "MaruSettings")
    }

    /// `-MaruStorageError corrupt`: the open fails with this error. The database files are not opened or changed.
    static var storageError: StorageError? {
        switch UserDefaults.standard.string(forKey: "MaruStorageError") {
        case "corrupt": .corrupt
        case "newerSchema": .newerSchema
        case "migrationFailed": .migrationFailed
        case "diskFull": .diskFull
        case "unavailable": .unavailable
        default: nil
        }
    }
}

extension AppStore {
    /// The tap of a `-MaruScenario` scenario, else the reminder of `DebugLaunch.tap` as the system would deliver it,
    /// with the `userInfo` of the plan.
    /// When the plan does not read, for example with `-MaruStorageError unavailable`, it has only the series ID.
    func debugTap(at now: Date, deviceTimeZone: NamedTimeZone) async -> DeliveredReminder? {
        if let tap = debug.launchTap {
            debug.launchTap = nil
            return tap
        }
        guard let tap = DebugLaunch.tap else { return nil }
        // Only the `userInfo` matters here. Neutral text keeps one daily request for a series of every day (D029).
        let plan = try? await open().reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: .hideNames)
        let request = plan?.requests.first { $0.trigger.time == tap.time && $0.trigger.weekday == nil }
        let seriesID = "series|device|\(String(format: "%02d:%02d", tap.time.hour, tap.time.minute))"
        let planned = deviceTimeZone.resolve(tap.time, on: LocalDate(now, in: deviceTimeZone)).earliestInstant
        return DeliveredReminder(
            deliveredAt: planned.addingTimeInterval(Double(tap.delay) * 60),
            userInfo: request?.userInfo ?? [ReminderRequest.seriesIDKey: seriesID],
            triggerWeekday: nil
        )
    }

    /// Made-up supplements with no dose. They are not the data of a person.
    /// An item with no time has no schedule, so it shows only in My Items (T02).
    private static let samples: [(name: String, form: ItemForm, amount: String?, times: [(hour: Int, minute: Int)])] = [
        ("Vitamin D", .drop, nil, [(8, 0)]),
        ("Omega-3", .softgel, "2 softgels", [(8, 0), (20, 0)]),
        ("Zinc", .tablet, nil, [(12, 30)]),
        ("Creatine", .powder, "1 scoop", [(13, 0)]),
        ("Magnesium glycinate", .capsule, "2 capsules", [(21, 30)]),
        ("Probiotic", .unknown, nil, []),
    ]

    func loadSampleData(at now: Date, deviceTimeZone: NamedTimeZone) async throws {
        let store = try open()
        guard try await store.items().isEmpty else { return }
        var items: [Item] = []
        for sample in DebugLaunch.onlyOneSample ? Array(Self.samples.prefix(1)) : Self.samples {
            // Each sample gets the color that the edit screen gives a new item, so the colors differ (D021).
            let item = try Item(
                category: .supplement,
                name: sample.name,
                form: sample.form,
                color: .forNewItem(among: items)
            )
            try await store.save(item)
            items.append(item)
            guard !sample.times.isEmpty else { continue }
            var schedule = Schedule(itemID: item.id, isEnabled: true)
            let slotTimes = try sample.times.map { time in
                SlotTime(slotID: try schedule.addSlot().id, time: try WallClockTime(hour: time.hour, minute: time.minute))
            }
            try schedule.appendVersion(
                ScheduleVersion(
                    scheduleID: schedule.id,
                    effectiveFrom: LocalDate(now, in: deviceTimeZone).adding(days: -DebugLaunch.sampleHistoryDays),
                    weeklyRule: .everyDay,
                    slotTimes: slotTimes,
                    dose: sample.amount.flatMap(Dose.init),
                    timeZonePolicy: .followsDevice
                )
            )
            try await store.save(schedule)
        }
        if DebugLaunch.wantsSampleRecords { try await recordSamples(at: now, deviceTimeZone: deviceTimeZone) }
        if DebugLaunch.wantsSampleHistory { try await recordSampleHistory(at: now, deviceTimeZone: deviceTimeZone) }
    }

    /// Past doses: most taken at the planned time, one recorded later, one skipped, and some with no record.
    private func recordSampleHistory(at now: Date, deviceTimeZone: NamedTimeZone) async throws {
        let store = try open()
        let page = try await store.history(before: LocalDate(now, in: deviceTimeZone), days: DebugLaunch.sampleHistoryDays, deviceTimeZone: deviceTimeZone)
        for (dayIndex, day) in page.days.enumerated() {
            for (index, dose) in day.doses.enumerated() where (index + dayIndex) % 4 != 3 {
                let planned = dose.occurrence.resolvedTime.earliestInstant
                let action: IntakeAction = (index + dayIndex) % 5 == 2 ? .skipped : .taken
                let recordedAt = index == 1 ? planned.addingTimeInterval(95 * 60) : planned.addingTimeInterval(2 * 60)
                let event = IntakeEvent(
                    occurrenceID: dose.occurrence.id,
                    action: action,
                    occurredAt: index == 1 ? planned : recordedAt,
                    recordedAt: recordedAt,
                    source: .app
                )
                try await store.recordBackfill(event, occurrence: dose.occurrence)
            }
        }
    }

    /// Morning taken, the first noon item taken, and the first evening item skipped.
    private func recordSamples(at now: Date, deviceTimeZone: NamedTimeZone) async throws {
        let store = try open()
        let occurrences = TodaySnapshot.today(
            try await store.generateOccurrences(at: now, deviceTimeZone: deviceTimeZone), at: now
        )
        let morning = occurrences.filter { DayPart($0.plannedTime) == .morning }
        let noon = occurrences.filter { DayPart($0.plannedTime) == .noon }.prefix(1)
        let evening = occurrences.filter { DayPart($0.plannedTime) == .evening }.prefix(1)
        let events = (morning + noon).map { ($0, IntakeAction.taken) } + evening.map { ($0, IntakeAction.skipped) }
        try await store.record(events.map { occurrence, action in
            (
                IntakeEvent(occurrenceID: occurrence.id, action: action, occurredAt: now, recordedAt: now, source: .app),
                occurrence.scheduleVersionID
            )
        })
    }
}
#endif
