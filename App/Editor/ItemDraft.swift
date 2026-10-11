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

    /// A plan that repeats every second day (D036).
    struct EveryOtherDay: Codable, Equatable {
        /// The start date: the stored one of the plan, or the calendar date that a first-day choice had at the
        /// moment of the tap. It is a date and not "today" or "tomorrow", so a save on a later day, or a draft
        /// that comes back on a later day, keeps the rhythm. `nil` until the user chooses: the app picks no day.
        var start: Day?
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
    var name = ""
    /// A new item starts as a supplement, and the user can change it (D032).
    var category = ItemCategory.supplement
    /// A new item starts as a capsule, and the user can change it. The app does not guess it from the name (D013, D032).
    var form = ItemForm.capsule
    var color: ItemColor
    /// Free text, for example "1 capsule" or "1000 IU". Blank means no amount. There is no default (spec 2.1).
    var amount = ""
    var times: [Time] = []
    var weekdays = Set(Weekday.allCases)
    /// `nil` means that the plan repeats on `weekdays`. Else it repeats every second day, and the weekdays do not count.
    /// It is optional, so a draft file from before D036 still loads.
    var everyOtherDay: EveryOtherDay?
    var note = Note.none
    var noteText = ""

    /// A new item with no amount and no time (spec 2.1). The type, the form, and the color have a start value (D021, D032).
    init(color: ItemColor) {
        itemID = UUID()
        scheduleID = UUID()
        self.color = color
    }

    /// The stored item and the version of its schedule that applies now. A plan of every second day keeps
    /// its stored start date.
    init(item: Item, schedule: Schedule?) {
        itemID = item.id.rawValue
        scheduleID = schedule?.id.rawValue ?? UUID()
        name = item.name
        category = item.category
        form = item.form
        color = item.color
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
            everyOtherDay = version.everyOtherDayFrom.map { EveryOtherDay(start: Day($0)) }
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
    /// The plan repeats every second day, and the user did not choose its first day yet.
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
        if everyOtherDay == nil, weekdays.isEmpty { return .noWeekday }
        if let everyOtherDay, everyOtherDay.start?.date == nil { return .noFirstDay }
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
    /// A plan of every second day starts on the date in the draft: the stored start date, or the date of a
    /// first-day choice. The date of the save does not change it, so an edit of a time or of the amount does
    /// not move the rhythm, also when the save comes on a later day (D036).
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
        var item = try existingItem ?? Item(id: ItemID(itemID), category: category, name: name, form: form, color: color)
        try item.rename(name)
        item.category = category
        item.form = form
        item.color = color
        item.intakeNote = intakeNote

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
        let weeklyRule = try everyOtherDay == nil ? WeeklyRule(weekdays: weekdays) : .everyDay
        var everyOtherDayFrom = everyOtherDay?.start?.date
        guard everyOtherDay == nil || everyOtherDayFrom != nil else { throw DraftBuildError.noFirstDay }
        // A choice that gives the due dates of the stored plan is no change of the plan.
        if let first = everyOtherDayFrom, let stored = latest?.everyOtherDayFrom,
           first >= stored, first.days(since: stored).isMultiple(of: 2) {
            everyOtherDayFrom = stored
        }
        let dose = Dose(amount)
        if let latest,
           latest.weeklyRule == weeklyRule,
           latest.everyOtherDayFrom == everyOtherDayFrom,
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
                everyOtherDayFrom: everyOtherDayFrom,
                slotTimes: slotTimes,
                dose: dose,
                timeZonePolicy: timeZonePolicy,
                productVersionID: latest?.productVersionID
            )
        )
        return (item, schedule)
    }
}

enum DraftBuildError: Error {
    case noTimeZone
    case noFirstDay
    case laterVersion(LocalDate)
}

// The draft file keeps the raw values. The conformances live in the app, so `MaruCore` does not change.
extension ItemCategory: @retroactive Codable {}
extension ItemForm: @retroactive Codable {}
extension ItemColor: @retroactive Codable {}
extension Weekday: @retroactive Codable {}
