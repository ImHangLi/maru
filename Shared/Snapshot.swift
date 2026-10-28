import Foundation
import MaruCore

/// What the two tabs show: a light projection of the store (spec 9). It has only the values that the views draw.
struct Snapshot: Equatable, Sendable {
    /// `nil` when the time zone of the device has no region name. See `NamedTimeZone.init(device:)`.
    var today: TodaySnapshot?
    /// The active items, in the order of the first save.
    let list: [ListEntry]
    /// The archived items, for the "Archived" entry at the end of My Items (spec 3 P02).
    var archived: [ListEntry] = []
    /// Every member of the Family, archived or not, in the order of the first save (D121). The first one is "Me".
    var people: [Person] = []

    /// `false` when the day or the time zone is not the one of the read, so Today must not show this content (spec 9).
    /// A snapshot with no Today is current while the device time zone still has no region name.
    func isCurrent(at now: Date, deviceTimeZone: NamedTimeZone?) -> Bool {
        today?.isCurrent(at: now, deviceTimeZone: deviceTimeZone) ?? (deviceTimeZone == nil)
    }
}

struct ListEntry: Identifiable, Equatable, Sendable {
    let id: ItemID
    let personID: PersonID
    /// The owner for a text: `nil` when the Family has one active member (D123).
    var owner: DoseOwner?
    let name: String
    let form: ItemForm
    let color: ItemColor
    /// The photo file of the item, or `nil` (D056). The row draws the form icon until the photo loads.
    let imageReference: String?
    /// The item has a schedule with its reminders off (T07).
    var remindersOff = false
}

/// The occurrences of one day. It has its date and the time of the read, so the content of another day
/// cannot show as today (spec 9).
struct TodaySnapshot: Equatable, Sendable {
    /// What a row draws for an item: the user's name, form, color, and amount.
    struct ItemLook: Equatable, Sendable {
        /// The name area of a row opens the detail of this item (spec 3 P01).
        let itemID: ItemID
        /// The member of the item (D121). A view that filters by member reads it.
        let personID: PersonID
        let name: String
        let form: ItemForm
        let color: ItemColor
        /// The owner for a text: `nil` when the Family has one active member (D123). `labelledName` has the text.
        var owner: DoseOwner?
        /// The reminders of the item are off. The row stays, and the user can still record it (T07).
        var remindersOff = false
        /// The photo file of the item, or `nil` (D056). The app draws it. The widgets draw the form icon.
        var imageReference: String?
    }

    /// One row: one occurrence of today and its record.
    struct Entry: Identifiable, Equatable, Sendable {
        let occurrence: Occurrence
        let look: ItemLook
        /// The amount that the user typed, from the schedule version of the occurrence. `nil` when there is none.
        let amount: String?
        /// The stored history. The row shows its current state, and a correction revises its last event.
        var record: OccurrenceRecord

        var id: OccurrenceID { occurrence.id }
        var isOpen: Bool { record.status == .unrecorded }
    }

    struct Group: Identifiable, Equatable, Sendable {
        let part: DayPart
        var entries: [Entry]

        var id: DayPart { part }
    }

    /// A snapshot of this age or more is not current. The time is shorter than each calendar day,
    /// so no time zone has two midnights in it.
    static let longestAge: TimeInterval = 12 * 60 * 60

    let generatedAt: Date
    let date: LocalDate
    let timeZone: NamedTimeZone
    /// The parts of the day that have an occurrence, in the order of the day. The rows keep their order
    /// after a record, so nothing moves under the finger (spec 4).
    private(set) var groups: [Group]
    /// The card at the end of the page. It is empty when the day has no as-needed item and no dose (D021).
    var asNeeded = AsNeededCard()
    /// The time zones that decide "today" for this content: the zone of the device, the zone of each
    /// occurrence of the run, and the zone of each schedule version that the run read. A midnight in an
    /// occurrence zone moves a row to another day. A midnight in a plan zone can make a stored row past,
    /// or not past, so the next run can keep it or leave it out.
    private let zones: Set<NamedTimeZone>

    /// - Parameters:
    ///   - occurrences: The result of a generation run at `now`, in the order of the planned instant.
    ///   - planZones: The time zones of the schedule versions that the run read.
    ///   - looks: The item of each slot.
    ///   - doses: The dose of each schedule version that has one.
    ///   - records: The record of each occurrence of today.
    init(
        now: Date,
        timeZone: NamedTimeZone,
        occurrences: [Occurrence],
        planZones: Set<NamedTimeZone>,
        looks: [ScheduleSlotID: ItemLook],
        doses: [ScheduleVersionID: Dose],
        records: [OccurrenceID: OccurrenceRecord]
    ) {
        generatedAt = now
        date = LocalDate(now, in: timeZone)
        self.timeZone = timeZone
        zones = Set(occurrences.map(\.timeZone)).union(planZones).union([timeZone])
        let today = Self.today(occurrences, at: now)
        groups = DayPart.allCases.compactMap { part in
            let entries = today.filter { DayPart($0.plannedTime) == part }.compactMap { occurrence in
                looks[occurrence.slotID].map {
                    Entry(
                        occurrence: occurrence,
                        look: $0,
                        amount: doses[occurrence.scheduleVersionID]?.text,
                        record: records[occurrence.id] ?? OccurrenceRecord(occurrenceID: occurrence.id)
                    )
                }
            }
            return entries.isEmpty ? nil : Group(part: part, entries: entries)
        }
    }

    /// A run also gives yesterday and tomorrow. An occurrence is of today by the date in its own time zone,
    /// so a schedule with a fixed zone keeps its own calendar (spec 8.5).
    static func today(_ occurrences: [Occurrence], at now: Date) -> [Occurrence] {
        occurrences.filter { isToday($0.plannedDate, in: $0.timeZone, at: now) }
    }

    /// A date is today by the date of `now` in its time zone. The reminder choice uses the same rule.
    static func isToday(_ date: LocalDate, in timeZone: NamedTimeZone, at now: Date) -> Bool {
        date == LocalDate(now, in: timeZone)
    }

    var entries: [Entry] { groups.flatMap(\.entries) }

    /// Puts committed records in place. The rows keep their places.
    mutating func apply(_ records: [OccurrenceRecord]) {
        for record in records {
            for g in groups.indices {
                if let e = groups[g].entries.firstIndex(where: { $0.id == record.occurrenceID }) {
                    groups[g].entries[e].record = record
                }
            }
        }
    }

    /// `true` while the device has the time zone of the read, and no zone of `zones` crossed a midnight
    /// since the read. An occurrence is of today by the date in its own time zone, so the date of the device
    /// alone does not decide.
    func isCurrent(at now: Date, deviceTimeZone: NamedTimeZone?) -> Bool {
        timeZone == deviceTimeZone
            && abs(now.timeIntervalSince(generatedAt)) < Self.longestAge
            && zones.allSatisfy { LocalDate(now, in: $0) == LocalDate(generatedAt, in: $0) }
    }

    /// The first instant after the read at which `isCurrent` can become `false` with no change of the device zone:
    /// the next midnight in a zone of `zones`, or the end of `longestAge`.
    var expiresAt: Date {
        let midnights = zones.compactMap { zone -> Date? in
            guard let timeZone = TimeZone(identifier: zone.identifier) else { return nil }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            // The start of a day can be later than 00:00, where a clock change skips midnight.
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: generatedAt))
                .map(calendar.startOfDay(for:))
        }
        return (midnights + [generatedAt.addingTimeInterval(Self.longestAge)]).min()!
    }
}

extension NamedTimeZone {
    /// The time zone of the device as the domain accepts it.
    ///
    /// The domain accepts a region name such as `Asia/Shanghai`, and `UTC` (spec 8.5). A zone with another name,
    /// with no offset from UTC, and with no clock change, for example `GMT`, is the same clock as `UTC`.
    /// An offset-only zone such as `GMT+0800` has no region. The app does not choose a region for the user (spec 2),
    /// so the result is `nil`, and the app generates nothing.
    init?(device timeZone: TimeZone, at now: Date) {
        if let zone = try? NamedTimeZone(identifier: timeZone.identifier) {
            self = zone
        } else if timeZone.secondsFromGMT(for: now) == 0, timeZone.nextDaylightSavingTimeTransition(after: now) == nil {
            self = .utc
        } else {
            return nil
        }
    }
}
