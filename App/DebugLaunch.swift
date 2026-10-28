#if DEBUG
import Foundation
import MaruCore
import MaruDatabase

/// Launch arguments of a debug build, for screenshots and manual checks. A release build does not have this code.
enum DebugLaunch {
    /// `-MaruSampleData YES`: load the sample items when the store has no item.
    static var wantsSampleData: Bool {
        UserDefaults.standard.bool(forKey: "MaruSampleData")
    }

    /// `-MaruSampleRecords YES`: with the sample items, record the morning of today as taken and a history of
    /// 80 days, through the record transaction. For screenshots of recorded rows and of the history.
    static var wantsSampleRecords: Bool {
        UserDefaults.standard.bool(forKey: "MaruSampleRecords")
    }

    /// `-MaruFirstRun YES`: show the onboarding again, as after a new install (D103).
    /// For a check on a device or a simulator that already showed it. The onboarding still needs a store with no item.
    static var wantsFirstRun: Bool {
        UserDefaults.standard.bool(forKey: "MaruFirstRun")
    }

    /// `-MaruDebugPro YES`: act as if Maru Pro is active, with no purchase. For the check of the Watch app in a
    /// simulator (D111). Without it, the purchase of the StoreKit configuration decides.
    static var forcesPro: Bool {
        UserDefaults.standard.bool(forKey: "MaruDebugPro")
    }

    /// `-MaruPaywallStyleB1 YES` or `-MaruPaywallStyleB2 YES`: show the second paywall (style B, D116, D117) in its immersive
    /// or its clean look instead of the plain one of D115, so the looks can be captured. A release build always shows the
    /// plain one until the maintainer picks a style.
    static var paywallLook: PaywallStyleB.Look? {
        if UserDefaults.standard.bool(forKey: "MaruPaywallStyleB1") { return .immersive }
        if UserDefaults.standard.bool(forKey: "MaruPaywallStyleB2") { return .clean }
        return nil
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
}

extension AppStore {
    /// The tap of a `-MaruScenario` scenario, else the reminder of `DebugLaunch.tap` as the system would deliver it,
    /// with the `userInfo` of the plan.
    /// When the plan does not read, it has only the series ID.
    func debugTap(at now: Date, deviceTimeZone: NamedTimeZone) async -> DeliveredReminder? {
        if let tap = debug.launchTap {
            debug.launchTap = nil
            return tap
        }
        guard let tap = DebugLaunch.tap else { return nil }
        // Only the `userInfo` matters here. Neutral text keeps one daily request for a series of every day (D029).
        let plan = try? await open().reminderPlan(at: now, deviceTimeZone: deviceTimeZone, privacy: .hideNames)
        let request = plan?.requests.first { $0.trigger.time == tap.time && $0.trigger.weekday == nil && $0.trigger.repeats }
        let seriesID = "series|device|\(String(format: "%02d:%02d", tap.time.hour, tap.time.minute))"
        let planned = deviceTimeZone.resolve(tap.time, on: LocalDate(now, in: deviceTimeZone)).earliestInstant
        return DeliveredReminder(
            deliveredAt: planned.addingTimeInterval(Double(tap.delay) * 60),
            userInfo: request?.userInfo ?? [ReminderRequest.seriesIDKey: seriesID],
            triggerWeekday: nil
        )
    }

    /// The supplements and medications that many people take in the market of the app language, with the generic
    /// names and the dose words of that language (D070). They are not the data of a person. Each language has the
    /// same shape: the same forms and times, so the pictures stay comparable.
    /// An item with no time has no schedule, so it is as needed (D021).
    /// Vitamin D3, omega-3, and magnesium have a photo of a jar with an invented brand, so a screenshot shows photo
    /// icons next to drawn icons. A medication never has one (D073).
    private typealias Sample = (
        name: String, category: ItemCategory, form: ItemForm, amount: String?, times: [(hour: Int, minute: Int)],
        photo: String?
    )
    private static let samplesByLanguage: [String: [Sample]] = [
        "en": [
            ("Vitamin D3", .supplement, .softgel, "1 softgel", [(8, 0)], "vitd3"),
            ("Levothyroxine", .medication, .tablet, "1 tablet", [(7, 0)], nil),
            ("Omega-3", .supplement, .softgel, "2 softgels", [(12, 30)], "omega3"),
            ("Magnesium Glycinate", .supplement, .capsule, "2 capsules", [(21, 0)], "magnesium"),
            ("Atorvastatin", .medication, .tablet, "1 tablet", [(21, 0)], nil),
            ("Ibuprofen", .medication, .tablet, nil, [], nil),
        ],
        "zh-Hans": [
            ("维生素 D3", .supplement, .softgel, "1 粒", [(8, 0)], "vitd3"),
            ("氨氯地平", .medication, .tablet, "1 片", [(7, 0)], nil),
            ("鱼油", .supplement, .softgel, "2 粒", [(12, 30)], "omega3"),
            ("甘氨酸镁", .supplement, .capsule, "2 粒", [(21, 0)], "magnesium"),
            ("阿托伐他汀", .medication, .tablet, "1 片", [(21, 0)], nil),
            ("布洛芬", .medication, .tablet, nil, [], nil),
        ],
        "ja": [
            ("ビタミンD3", .supplement, .softgel, "1粒", [(8, 0)], "vitd3"),
            ("アムロジピン", .medication, .tablet, "1錠", [(7, 0)], nil),
            ("DHA・EPA", .supplement, .softgel, "2粒", [(12, 30)], "omega3"),
            ("マグネシウム", .supplement, .capsule, "2粒", [(21, 0)], "magnesium"),
            ("ロスバスタチン", .medication, .tablet, "1錠", [(21, 0)], nil),
            ("ロキソプロフェン", .medication, .tablet, nil, [], nil),
        ],
        "ko": [
            ("비타민 D3", .supplement, .softgel, "1캡슐", [(8, 0)], "vitd3"),
            ("암로디핀", .medication, .tablet, "1정", [(7, 0)], nil),
            ("오메가3", .supplement, .softgel, "2캡슐", [(12, 30)], "omega3"),
            ("마그네슘", .supplement, .capsule, "2캡슐", [(21, 0)], "magnesium"),
            ("아토르바스타틴", .medication, .tablet, "1정", [(21, 0)], nil),
            ("아세트아미노펜", .medication, .tablet, nil, [], nil),
        ],
        "es": [
            ("Vitamina D3", .supplement, .softgel, "1 cápsula blanda", [(8, 0)], "vitd3"),
            ("Levotiroxina", .medication, .tablet, "1 comprimido", [(7, 0)], nil),
            ("Omega 3", .supplement, .softgel, "2 cápsulas blandas", [(12, 30)], "omega3"),
            ("Glicinato de magnesio", .supplement, .capsule, "2 cápsulas", [(21, 0)], "magnesium"),
            ("Atorvastatina", .medication, .tablet, "1 comprimido", [(21, 0)], nil),
            ("Paracetamol", .medication, .tablet, nil, [], nil),
        ],
        "de": [
            ("Vitamin D3", .supplement, .softgel, "1 Kapsel", [(8, 0)], "vitd3"),
            ("Levothyroxin", .medication, .tablet, "1 Tablette", [(7, 0)], nil),
            ("Omega-3", .supplement, .softgel, "2 Kapseln", [(12, 30)], "omega3"),
            ("Magnesiumglycinat", .supplement, .capsule, "2 Kapseln", [(21, 0)], "magnesium"),
            ("Simvastatin", .medication, .tablet, "1 Tablette", [(21, 0)], nil),
            ("Ibuprofen", .medication, .tablet, nil, [], nil),
        ],
    ]

    private static var samples: [Sample] {
        samplesByLanguage[Bundle.main.preferredLocalizations.first ?? "en"] ?? samplesByLanguage["en"]!
    }

    /// Stores a sample photo as the edit screen stores a cut-out: a PNG of at most `ItemPhotos.maxPixel` pixels,
    /// written by `ItemPhotos` (D056). The files were made with the Vision steps of `PhotoProcessor`.
    /// Only a debug build has them (project.yml).
    private static func writeSamplePhoto(_ name: String) throws -> String {
        guard let url = Bundle.main.url(forResource: "sample-photo-\(name)", withExtension: "png") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try ItemPhotos.write(try Data(contentsOf: url), fileExtension: "png")
    }

    /// The sample records start this many days before today, so the graph of the history has 13 weeks or fewer.
    private static let sampleHistoryDays = 80

    func loadSampleData(at now: Date, deviceTimeZone: NamedTimeZone) async throws {
        let store = try open()
        guard try await store.items().isEmpty else { return }
        let today = LocalDate(now, in: deviceTimeZone)
        var items: [Item] = []
        var schedules: [Schedule] = []
        for sample in Self.samples {
            // Each sample gets the color that the edit screen gives a new item, so the colors differ (D021).
            let item = try Item(
                category: sample.category,
                name: sample.name,
                form: sample.form,
                color: .forNewItem(among: items),
                imageReference: try sample.photo.map(Self.writeSamplePhoto)
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
                    effectiveFrom: DebugLaunch.wantsSampleRecords ? today.adding(days: -Self.sampleHistoryDays) : today,
                    weeklyRule: .everyDay,
                    slotTimes: slotTimes,
                    dose: sample.amount.flatMap(Dose.init),
                    timeZonePolicy: .followsDevice
                )
            )
            try await store.save(schedule)
            schedules.append(schedule)
        }
        if DebugLaunch.wantsSampleRecords {
            try await recordSamples(schedules, at: now, deviceTimeZone: deviceTimeZone)
        }
    }

    /// The morning of today taken, and a history that looks like real use: most doses taken, some skipped or
    /// with no record, and some days with no record. The pattern is fixed, so each load gives the same graph.
    private func recordSamples(_ schedules: [Schedule], at now: Date, deviceTimeZone: NamedTimeZone) async throws {
        let store = try open()
        let today = LocalDate(now, in: deviceTimeZone)
        var events: [(event: IntakeEvent, scheduleVersionID: ScheduleVersionID)] = []
        func event(_ occurrence: Occurrence, _ action: IntakeAction) -> (event: IntakeEvent, scheduleVersionID: ScheduleVersionID) {
            // A few minutes after the planned time, and never after now.
            let planned = occurrence.timeZone.resolve(occurrence.plannedTime, on: occurrence.plannedDate).earliestInstant
            let time = min(planned.addingTimeInterval(4 * 60), now)
            return (
                IntakeEvent(occurrenceID: occurrence.id, action: action, occurredAt: time, recordedAt: time, source: .app),
                occurrence.scheduleVersionID
            )
        }
        for day in 1...Self.sampleHistoryDays where day % 23 != 9 {
            let date = today.adding(days: -day)
            let planned = schedules.flatMap { $0.plannedOccurrences(on: date, deviceTimeZone: deviceTimeZone) }
            for (index, plan) in planned.enumerated() where (day * 3 + index * 5) % 19 != 0 {
                // No generation run stores a day this old, so the sample stores the occurrence itself.
                let occurrence = Occurrence(
                    slotID: plan.slotID,
                    plannedDate: plan.plannedDate,
                    plannedTime: plan.plannedTime,
                    timeZone: plan.timeZone,
                    scheduleVersionID: plan.scheduleVersionID
                )
                try await store.save(occurrence)
                events.append(event(occurrence, (day + index) % 31 == 0 ? .skipped : .taken))
            }
        }
        let occurrences = TodaySnapshot.today(
            try await store.generateOccurrences(at: now, deviceTimeZone: deviceTimeZone), at: now
        )
        for occurrence in occurrences where DayPart(occurrence.plannedTime) == .morning {
            events.append(event(occurrence, .taken))
        }
        try await store.record(events)
    }
}
#endif
