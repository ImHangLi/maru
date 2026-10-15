import Foundation
@testable import MaruCore

/// The repeat rule of a simulated item.
enum SimDays: Sendable {
    case everyDay
    case weekdays(Set<Weekday>)
    case cycle(on: Int, off: Int, start: LocalDate)
}

/// The time zone rule of a simulated item.
enum SimZone: Sendable, Equatable {
    case device
    case fixed(NamedTimeZone)
}

/// One dose time of an item. An edit appends a time with the date from which it applies, as a schedule version does.
struct SimSlot: Sendable {
    let id: ScheduleSlotID
    var times: [(from: LocalDate, time: WallClockTime?)]

    func time(on date: LocalDate) -> WallClockTime? {
        times.last { $0.from <= date }?.time
    }
}

/// What the user did, as the test knows it. The oracle reads only this, and never the database or the engines,
/// so a bug in the engines cannot hide in the expected values.
struct SimItem: Sendable {
    let id: ItemID
    let scheduleID: ScheduleID
    var name: String
    var isArchived = false
    var isPaused = false
    var followUp: FollowUpSetting?
    var alarm = false
    var slots: [SimSlot]
    var days: SimDays
    var zone: SimZone

    func isDue(on date: LocalDate) -> Bool {
        switch days {
        case .everyDay: true
        case let .weekdays(weekdays): weekdays.contains(date.weekday)
        case let .cycle(on, off, start): date >= start && date.days(since: start) % (on + off) < on
        }
    }
}

/// One planned dose: one slot of one item on one plan date.
struct SimDose: Sendable {
    let item: SimItem
    let slot: ScheduleSlotID
    let date: LocalDate
    let time: WallClockTime
    let instant: Date
    let zone: NamedTimeZone
    /// The time zone rule of the item.
    let rule: SimZone

    var key: ClosedKey { ClosedKey(slot: slot, date: date) }
}

struct ClosedKey: Hashable, Sendable {
    let slot: ScheduleSlotID
    let date: LocalDate
}

/// The facts of the user's data, kept apart from the app.
struct Truth: Sendable {
    /// In the order of creation, which is the order of the schedules in the database.
    var items: [SimItem] = []
    var closed: Set<ClosedKey> = []
    /// The snoozes of the user that have not ended (D090).
    var snoozes: [SimSnooze] = []

    /// Every dose of every item that Today can show, with an instant in `(from, through]`, in time order.
    /// An archived item has none. A paused item has them, because Today still shows them.
    func doses(from: Date, through: Date, deviceZone: NamedTimeZone) -> [SimDose] {
        var result: [SimDose] = []
        let first = LocalDate(from, in: .utc).adding(days: -2)
        let last = LocalDate(through, in: .utc).adding(days: 2)
        for item in items where !item.isArchived {
            let zone: NamedTimeZone = switch item.zone {
            case .device: deviceZone
            case let .fixed(zone): zone
            }
            var date = first
            while date <= last {
                if item.isDue(on: date) {
                    for slot in item.slots {
                        guard let time = slot.time(on: date) else { continue }
                        let instant = zone.resolve(time, on: date).earliestInstant
                        if instant > from, instant <= through {
                            result.append(
                                SimDose(item: item, slot: slot.id, date: date, time: time, instant: instant, zone: zone, rule: item.zone)
                            )
                        }
                    }
                }
                date = date.adding(days: 1)
            }
        }
        return result.sorted { ($0.instant, $0.item.name) < ($1.instant, $1.item.name) }
    }

    func isOpen(_ dose: SimDose) -> Bool { !closed.contains(dose.key) }

    func index(of name: String) -> Int {
        items.firstIndex { $0.name == name }!
    }
}

/// A "Remind in 10 min" that the user chose (D090). The group is the time of day and the plan date of the notification.
struct SimSnooze: Sendable {
    let date: LocalDate
    let time: WallClockTime
    /// The instant at which the reminder comes again.
    let fireAt: Date
}

extension Truth {
    /// The open doses of every item that reminds, at `time` on `date`. A paused item is not in a group (as for `doses`).
    func openDoses(on date: LocalDate, at time: WallClockTime, deviceZone: NamedTimeZone) -> [SimDose] {
        items.filter { !$0.isArchived && !$0.isPaused && $0.isDue(on: date) }.flatMap { item -> [SimDose] in
            let zone: NamedTimeZone = switch item.zone {
            case .device: deviceZone
            case let .fixed(zone): zone
            }
            return item.slots.compactMap { slot in
                guard slot.time(on: date) == time else { return nil }
                let dose = SimDose(
                    item: item, slot: slot.id, date: date, time: time, instant: zone.resolve(time, on: date).earliestInstant,
                    zone: zone, rule: item.zone
                )
                return isOpen(dose) ? dose : nil
            }
        }
    }

    /// A snooze stands while its group has an open dose, and until 01:00 on the day after its date (D090). The user closes a dose
    /// in the app, or archives, pauses, or deletes an item, and the snooze goes with the last open dose of its group.
    mutating func pruneSnoozes(at now: Date, deviceZone: NamedTimeZone) {
        snoozes = snoozes.filter { snooze in
            let doses = openDoses(on: snooze.date, at: snooze.time, deviceZone: deviceZone)
            guard let zone = doses.first?.zone else { return false }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone.systemZone
            let next = snooze.date.adding(days: 1)
            let stop = calendar.date(from: DateComponents(year: next.year, month: next.month, day: next.day, hour: 1))!
            return now < stop
        }
    }
}
