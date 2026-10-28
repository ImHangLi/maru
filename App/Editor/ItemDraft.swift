import Foundation
import MaruCore

/// What the user typed on the edit screen, before the save (spec 3 P03).
///
/// It is a plain value, so the app can keep it in a file and offer it again after the app stops (P03).
/// The IDs are fixed when the draft starts, so a second save of the same draft does not add a second item.
struct ItemDraft: Codable, Equatable {
    /// One reminder time. Its ID is the slot ID: an edit of the time keeps the slot (spec 7.1).
    struct Time: Codable, Equatable, Identifiable {
        var id: UUID
        var hour: Int
        var minute: Int
    }

    enum Note: String, Codable, CaseIterable {
        case none, withFood, emptyStomach, custom
    }

    /// A plan that counts days from a start date: every other day (D036), every few days, or days with a dose
    /// and a pause after them (D065).
    struct Cycle: Codable, Equatable {
        enum Kind: String, Codable {
            case everyOtherDay, interval, pause
        }

        /// The choice on the repeat page. It decides which rows the page shows.
        var kind: Kind
        /// The start date: the stored one of the plan, or the calendar date that a first-day choice had at the
        /// moment of the tap. It is a date and not "today" or "tomorrow", so a save on a later day, or a draft
        /// that comes back on a later day, keeps the rhythm. `nil` until the user chooses: the app picks no day.
        var start: Day?
        /// The days with a dose, then the days with none. `nil` until the user chooses: the app picks no number.
        /// Every other day is 1 and 1. An interval of N days is 1 and N - 1.
        var daysOn: Int?
        var daysOff: Int?

        /// A new choice on the repeat page, with no first day. Only every other day has its numbers.
        init(kind: Kind) {
            self.kind = kind
            daysOn = kind == .pause ? nil : 1
            daysOff = kind == .everyOtherDay ? 1 : nil
        }

        /// The rule of a stored plan.
        init(_ cycle: DayCycle) {
            kind = switch (cycle.daysOn, cycle.daysOff) {
            case (1, 1): .everyOtherDay
            case (1, Self.intervals.lowerBound - 1...Self.intervals.upperBound - 1): .interval
            default: .pause
            }
            start = Day(cycle.start)
            daysOn = cycle.daysOn
            daysOff = cycle.daysOff
        }

        /// A draft file from before D065 has only the start date of a plan that repeats every second day.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            start = try container.decodeIfPresent(Day.self, forKey: .start)
            if let kind = try container.decodeIfPresent(Kind.self, forKey: .kind) {
                self.kind = kind
                daysOn = try container.decodeIfPresent(Int.self, forKey: .daysOn)
                daysOff = try container.decodeIfPresent(Int.self, forKey: .daysOff)
            } else {
                kind = .everyOtherDay
                daysOn = 1
                daysOff = 1
            }
        }

        /// The days from one dose to the next that "Every Few Days" offers. Two days is "Every Other Day".
        static let intervals = 3...30
        /// The days with a dose and the days with none, when the user chose them and the page offers them.
        var counts: (daysOn: Int, daysOff: Int)? {
            guard let daysOn, let daysOff, DayCycle.dayCounts.contains(daysOn), DayCycle.dayCounts.contains(daysOff) else { return nil }
            return (daysOn, daysOff)
        }
    }

    /// A calendar date in a form that the draft file keeps.
    struct Day: Codable, Equatable {
        var year: Int
        var month: Int
        var day: Int

        init(_ date: LocalDate) {
            year = date.year
            month = date.month
            day = date.day
        }

        var date: LocalDate? { try? LocalDate(year: year, month: month, day: day) }
    }

    var itemID: UUID
    var scheduleID: UUID
    /// The member that owns the item (D121). The editor sets it when the draft starts: the stored owner, or the default owner of a new
    /// item. A draft file from before the Family has none, and the editor fills it from the context.
    var personID: UUID?
    var name = ""
    /// A new item starts as a supplement, and the user can change it (D032).
    var category = ItemCategory.supplement
    /// A new item starts as a capsule, and the user can change it (D032). Until the user chooses a form, the edit
    /// screen sets the usual form of a known supplement, or the form on a scanned label (D043).
    var form = ItemForm.capsule
    var color: ItemColor
    /// Free text, for example "1 capsule" or "1000 IU". Blank means no amount. There is no default (spec 2.1).
    var amount = ""
    var times: [Time] = []
    var weekdays = Set(Weekday.allCases)
    /// `nil` means that the plan repeats on `weekdays`. Else it counts days, and the weekdays do not count.
    /// It is optional, so a draft file from before D036 still loads.
    var cycle: Cycle?
    var note = Note.none
    var noteText = ""
    /// The follow-ups of this item (D039, D079). `nil` means off. A draft file from before D079 has no value, so it loads as off.
    var followUp: FollowUpSetting?
    /// The alarm at each dose time (D079). `nil` means off, so a switch that goes back to off equals the stored item.
    var alarm: Bool?
    /// `true` when `followUp` and `alarm` hold the choice of the user. A draft file from before D079 has no value here,
    /// so the app takes both from the stored item and does not read them as "off" (D079).
    var hasReminderOptions: Bool? = true

    /// The draft file names `cycle` with its key from before D065, so an older file keeps its rule.
    /// A new property of the draft needs a case here, or the file does not keep it.
    private enum CodingKeys: String, CodingKey {
        case itemID, scheduleID, personID, name, category, form, color, amount, times, weekdays, note, noteText, followUp, alarm, hasReminderOptions
        case cycle = "everyOtherDay"
    }

    /// A new item with no amount and no time (spec 2.1). The type, the form, and the color have a start value (D021, D032).
    init(color: ItemColor) {
        itemID = UUID()
        scheduleID = UUID()
        self.color = color
    }

    /// A new item with the reminder style that the user last chose in Settings (D085). The style is not a dose or a
    /// time, so a start value is allowed (spec 2.1). The draft keeps it only when the item gets a time.
    /// The alarm starts on only when alarms can ring now (iOS 26 and allowed), so a permission that the user took back later does not start an item on.
    init(color: ItemColor, reminders: NewItemReminders) {
        self.init(color: color)
        followUp = reminders.followUpSetting
        if reminders.alarm, AlarmSupport.isAuthorized { alarm = true }
    }

    /// The stored item and the version of its schedule that applies now. A plan that counts days keeps
    /// its stored start date.
    init(item: Item, schedule: Schedule?) {
        itemID = item.id.rawValue
        scheduleID = schedule?.id.rawValue ?? UUID()
        personID = item.personID.rawValue
        name = item.name
        category = item.category
        form = item.form
        color = item.color
        followUp = item.followUp
        alarm = item.alarm ? true : nil
        switch item.intakeNote {
        case nil: break
        case .preset(.withFood): note = .withFood
        case .preset(.emptyStomach): note = .emptyStomach
        case let .text(text):
            note = .custom
            noteText = text
        }
        if let version = schedule?.versions.last {
            amount = version.dose?.text ?? ""
            times = version.slotTimes.map { Time(id: $0.slotID.rawValue, hour: $0.time.hour, minute: $0.time.minute) }
            weekdays = version.weeklyRule.weekdays
            cycle = version.dayCycle.map(Cycle.init)
        } else {
            // An item with no time keeps its usual amount on the item. Each dose that the user records copies it (D091).
            amount = item.asNeededDose?.text ?? ""
        }
    }

    /// A new item that replaces `item` (T06): the type, form, color, times, days, and note of the old item,
    /// with new IDs. The name stays for the user to edit. The amount is empty: the app converts no amount.
    static func replacing(_ item: Item, schedule: Schedule?) -> ItemDraft {
        var draft = ItemDraft(item: item, schedule: schedule)
        draft.itemID = UUID()
        draft.scheduleID = UUID()
        draft.times = draft.times.map { Time(id: UUID(), hour: $0.hour, minute: $0.minute) }
        draft.amount = ""
        return draft
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The times in the order of the day.
    var sortedTimes: [Time] {
        times.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    var hasDuplicateTimes: Bool {
        Set(times.map { $0.hour * 60 + $0.minute }).count != times.count
    }

    /// Supplements follow the life time of the device. A medication, or an item with no type, keeps the
    /// named zone where the user confirmed it (spec 8.5).
    var followsDevice: Bool {
        category == .supplement
    }

    /// Today in the zone of the plan: the kept zone of a medication, else the zone of the device.
    /// A first-day choice stores this date, or the date after it. `nil` when the device zone has no region name.
    func today(keptZoneFrom schedule: Schedule?, now: Date = .now) -> LocalDate? {
        (keptTimeZone(from: schedule) ?? NamedTimeZone(device: .current, at: now)).map { LocalDate(now, in: $0) }
    }

    /// The named zone that a medication keeps from its stored plan (spec 8.5). `nil` for a supplement or a new plan.
    func keptTimeZone(from schedule: Schedule?) -> NamedTimeZone? {
        guard !followsDevice, case let .fixed(zone)? = schedule?.versions.last?.timeZonePolicy else { return nil }
        return zone
    }
}

/// Why the draft cannot be saved yet. The preview line shows it in place of the schedule.
enum DraftProblem: Equatable {
    case noName
    case noWeekday
    /// The plan counts days, and the user did not choose the number of days yet.
    case noDayCount
    /// The plan counts days, and the user did not choose its first day yet.
    case noFirstDay
    case duplicateTime
    /// The device time zone has no region name, so a medication time has no zone to keep (spec 8.5).
    case noTimeZone
    /// The latest stored version starts after today, for example after a flight west. A version never starts
    /// before the one before it (spec 7.1), so a change to the plan waits until that date.
    case laterVersion(LocalDate)
}

extension ItemDraft {
    func problem(
        item: Item?,
        schedule: Schedule?,
        keptZoneFrom zoneSchedule: Schedule? = nil,
        now: Date,
        deviceTimeZone: NamedTimeZone?
    ) -> DraftProblem? {
        if trimmedName.isEmpty { return .noName }
        guard !times.isEmpty else { return nil }
        if cycle == nil, weekdays.isEmpty { return .noWeekday }
        if let cycle, cycle.counts == nil { return .noDayCount }
        if let cycle, cycle.start?.date == nil { return .noFirstDay }
        if hasDuplicateTimes { return .duplicateTime }
        if deviceTimeZone == nil { return .noTimeZone }
        do {
            _ = try build(item: item, schedule: schedule, keptZoneFrom: zoneSchedule, now: now, deviceTimeZone: deviceTimeZone)
        } catch let DraftBuildError.laterVersion(date) {
            return .laterVersion(date)
        } catch {
            // Save shows any other failure.
        }
        return nil
    }

    /// The item and the schedule to save.
    ///
    /// With no time, a new item has no schedule: it is a list-only item with no reminder (T02).
    /// A change of the times, the days, or the amount appends a schedule version that applies from today.
    /// A plan that counts days starts on the date in the draft: the stored start date, or the date of a
    /// first-day choice. The date of the save does not change it, so an edit of a time or of the amount does
    /// not move the rhythm, also when the save comes on a later day (D036, D065).
    /// Milestone A offers no later start date and no end date (T10). An old version never changes (spec 7.1).
    /// `zoneSchedule` is the plan of a replaced item: a medication that replaces it keeps that zone (spec 8.5).
    func build(
        item existingItem: Item?,
        schedule existingSchedule: Schedule?,
        keptZoneFrom zoneSchedule: Schedule? = nil,
        now: Date,
        deviceTimeZone: NamedTimeZone?
    ) throws -> (item: Item, schedule: Schedule?) {
        let intakeNote: IntakeNote? = switch note {
        case .none: nil
        case .withFood: .preset(.withFood)
        case .emptyStomach: .preset(.emptyStomach)
        case .custom: noteText.allSatisfy(\.isWhitespace) ? nil : try IntakeNote.custom(noteText)
        }
        guard let owner = personID.map({ PersonID($0) }) ?? existingItem?.personID else { throw DraftBuildError.noOwner }
        var item = try existingItem ?? Item(id: ItemID(itemID), personID: owner, category: category, name: name, form: form, color: color)
        try item.rename(name)
        // A new owner of a stored item. The store sets `ownerChangedAt` (D123).
        item.personID = owner
        item.category = category
        item.form = form
        item.color = color
        item.intakeNote = intakeNote
        // The reminder options belong to the reminder time. An item with no time keeps none (D079).
        let chosen = times.isEmpty ? nil : followUp
        if item.followUp != chosen { item.followUpChanged = now }
        item.followUp = chosen
        item.alarm = !times.isEmpty && alarm == true
        // An item with a time has its amount in the plan. An item with no time keeps it for its as-needed doses (D091).
        item.asNeededDose = times.isEmpty ? Dose(amount) : nil

        guard !times.isEmpty else { return (item, existingSchedule) }
        guard let deviceTimeZone else { throw DraftBuildError.noTimeZone }

        var schedule = existingSchedule ?? Schedule(id: ScheduleID(scheduleID), itemID: item.id, isEnabled: true)
        let latest = schedule.versions.last
        // A type change between supplement and medication changes the rule. Else the stored rule stays,
        // so a medication keeps the zone where the user first confirmed it.
        let timeZonePolicy: TimeZonePolicy = followsDevice
            ? .followsDevice
            : .fixed(keptTimeZone(from: existingSchedule ?? zoneSchedule) ?? deviceTimeZone)
        let known = Set(schedule.slots.map(\.id))
        let slotTimes = try sortedTimes.map { time in
            let slotID = ScheduleSlotID(time.id)
            if !known.contains(slotID) { try schedule.addSlot(id: slotID) }
            return SlotTime(slotID: slotID, time: try WallClockTime(hour: time.hour, minute: time.minute))
        }
        let zone = if case let .fixed(zone) = timeZonePolicy { zone } else { deviceTimeZone }
        let today = LocalDate(now, in: zone)
        let weeklyRule = try cycle == nil ? WeeklyRule(weekdays: weekdays) : .everyDay
        var dayCycle = try cycle.map { cycle -> DayCycle in
            guard let counts = cycle.counts else { throw DraftBuildError.noDayCount }
            guard let start = cycle.start?.date else { throw DraftBuildError.noFirstDay }
            return try DayCycle(start: start, daysOn: counts.daysOn, daysOff: counts.daysOff)
        }
        // A choice that gives the due dates of the stored plan from today on is no change of the plan.
        // A moved first day with another due date from today on is a change (spec 2).
        if let new = dayCycle, let stored = latest?.dayCycle, new.hasSameDueDates(as: stored, from: today) {
            dayCycle = stored
        }
        let dose = Dose(amount)
        if let latest,
           latest.weeklyRule == weeklyRule,
           latest.dayCycle == dayCycle,
           latest.slotTimes == slotTimes,
           latest.dose == dose,
           latest.timeZonePolicy == timeZonePolicy {
            return (item, schedule)
        }
        // A change applies from today. A version never starts before the one before it (spec 7.1), and a stored
        // version never changes, so a change that cannot start today is not saved.
        if let latest, today < latest.effectiveFrom { throw DraftBuildError.laterVersion(latest.effectiveFrom) }
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: today,
                weeklyRule: weeklyRule,
                dayCycle: dayCycle,
                slotTimes: slotTimes,
                dose: dose,
                timeZonePolicy: timeZonePolicy
            )
        )
        return (item, schedule)
    }
}

enum DraftBuildError: Error {
    case noOwner
    case noTimeZone
    case noDayCount
    case noFirstDay
    case laterVersion(LocalDate)
}

// The draft file keeps the raw values. The conformances live in the app, so `MaruCore` does not change.
// `ItemColor` has its conformance in `MaruCore`, for the messages of the Watch app (D071).
extension ItemCategory: @retroactive Codable {}
extension ItemForm: @retroactive Codable {}
extension Weekday: @retroactive Codable {}
