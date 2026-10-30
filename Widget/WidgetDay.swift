import Foundation
import MaruCore
import MaruDatabase

/// What the two widgets draw for today. It is a plain copy of the rows of `TodaySnapshot` (D048).
struct WidgetDay: Sendable {
    struct Dose: Identifiable, Sendable {
        /// The occurrence and its schedule version, as the text of their IDs. A tap on the capsule sends them.
        let id: String
        let scheduleVersionID: String
        let name: String
        let amount: String?
        let status: OccurrenceStatus
        /// The instant of the read that made this row. A tap sends it back, so the store refuses the dose when its owner changed
        /// after it (D123).
        var readAt = Date.distantPast

        var isTaken: Bool { status == .taken }
        var isOpen: Bool { status == .unrecorded }
    }

    struct Slot: Identifiable, Sendable {
        let part: DayPart
        /// The first planned time of the slot, as an instant. The view formats it in the format of the user.
        let time: Date
        let doses: [Dose]

        var id: DayPart { part }
        var openCount: Int { doses.filter(\.isOpen).count }
    }

    /// The restore epoch of the data that this day was read from. A tap sends it back (D048).
    let epoch: Int
    let timeZone: TimeZone
    let slots: [Slot]
    /// The first planned time after the read that is not one of today's rows, for "All done, next 8:00".
    let nextTime: Date?
    /// The time after which the day is not today any more.
    let expiresAt: Date

    var doses: [Dose] { slots.flatMap(\.doses) }
    var takenCount: Int { doses.filter(\.isTaken).count }

    /// The part of the day of the clock at `date`.
    func clockPart(at date: Date) -> DayPart {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return DayPart(try! WallClockTime(hour: hour, minute: 0))
    }

    /// The slot of the clock now, or the next slot that has doses. After the last slot it is the last slot.
    /// "Record Dose" shows it, also when every dose of it is taken, so a record fills the capsule in place.
    func slotAtClock(at date: Date) -> Slot? {
        let order = DayPart.allCases
        let now = order.firstIndex(of: clockPart(at: date))!
        return slots.first { order.firstIndex(of: $0.part)! >= now } ?? slots.last
    }

    /// The slot that "Today" shows: the first slot from the clock on that has an open dose, else the first
    /// slot with an open dose that the user missed. `nil` when every dose is done.
    func slotWithOpenDose(at date: Date) -> Slot? {
        let order = DayPart.allCases
        let now = order.firstIndex(of: clockPart(at: date))!
        let open = slots.filter { $0.openCount > 0 }
        return open.first { order.firstIndex(of: $0.part)! >= now } ?? open.first
    }

    /// The instants after `date` at which the part of the day changes, until the day ends.
    func partChanges(after date: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let midnight = calendar.startOfDay(for: date)
        let hours = (1..<24).filter {
            DayPart(try! WallClockTime(hour: $0, minute: 0)) != DayPart(try! WallClockTime(hour: $0 - 1, minute: 0))
        }
        return hours.compactMap { calendar.date(byAdding: .hour, value: $0, to: midnight) }
            .filter { $0 > date && $0 < expiresAt }
    }
}

extension WidgetDay {
    init(_ today: TodaySnapshot, occurrences: [Occurrence], epoch: Int, at now: Date) {
        self.epoch = epoch
        timeZone = TimeZone(identifier: today.timeZone.identifier) ?? .current
        slots = today.groups.map { group in
            Slot(
                part: group.part,
                time: group.entries.map { $0.occurrence.plannedInstant }.min() ?? now,
                doses: group.entries.map {
                    Dose(
                        id: $0.occurrence.id.rawValue.uuidString,
                        scheduleVersionID: $0.occurrence.scheduleVersionID.rawValue.uuidString,
                        name: $0.look.labelledName,
                        amount: $0.amount,
                        status: $0.record.status,
                        readAt: now
                    )
                }
            )
        }
        let todays = Set(today.entries.map(\.occurrence.id))
        nextTime = occurrences.filter { !todays.contains($0.id) && $0.plannedInstant > now }
            .map(\.plannedInstant).min()
        expiresAt = today.expiresAt
    }

    /// A day for the gallery and the placeholder. It has no name of the user.
    static let sample = WidgetDay(
        epoch: 0,
        timeZone: .current,
        slots: [
            Slot(part: .morning, time: Date(), doses: [
                Dose(id: "1", scheduleVersionID: "1", name: "Vitamin D", amount: "1 capsule", status: .taken),
                Dose(id: "2", scheduleVersionID: "1", name: "Omega 3", amount: "2 softgels", status: .unrecorded),
            ]),
            Slot(part: .noon, time: Date(), doses: [
                Dose(id: "3", scheduleVersionID: "1", name: "Zinc", amount: nil, status: .unrecorded),
            ]),
        ],
        nextTime: nil,
        expiresAt: .distantFuture
    )
}

extension Occurrence {
    /// The planned instant of the occurrence. It is not the time of an intake.
    var plannedInstant: Date {
        timeZone.resolve(plannedTime, on: plannedDate).earliestInstant
    }
}

extension TodaySnapshot {
    /// The rows of today from one read of the widget (D048). The widget stores nothing, so the read
    /// plans the occurrences in memory. See `LocalStore.readForWidget`.
    init(_ read: WidgetRead, at now: Date, deviceTimeZone: NamedTimeZone) {
        let family = Family(people: read.people)
        let looks = Dictionary(uniqueKeysWithValues: read.items.filter { !$0.isArchived }.map {
            ($0.id, ItemLook(itemID: $0.id, personID: $0.personID, name: $0.name, form: $0.form, color: $0.color, owner: family.owner(of: $0)))
        })
        self.init(
            now: now,
            timeZone: deviceTimeZone,
            occurrences: read.occurrences,
            planZones: read.planZones,
            looks: read.itemIDsBySlot.compactMapValues { looks[$0] },
            doses: read.doses,
            records: read.records
        )
    }
}
