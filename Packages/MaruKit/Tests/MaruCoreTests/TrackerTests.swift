import Foundation
import Testing
@testable import MaruCore

/// D091: the rules of the tracker that protect what the history says about the past.
@Suite("Tracker counts (D091)")
struct TrackerTests {
    /// An archived item keeps its past doses with no record up to the day before its archive. The day of the archive and
    /// later days show only records. An item archived before the app kept the time shows only its records.
    @Test func anArchivedItemKeepsItsPastNoRecordDoses() throws {
        var item = Fixtures.item()
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
        let dates = (3...6).map { Fixtures.date(2026, 3, $0) }
        func planned(_ item: Item) -> [LocalDate] {
            History.days(dates, items: [item], schedules: [schedule], stored: [], deviceTimeZone: Fixtures.shanghai)
                .filter { !$0.doses.isEmpty }.map(\.date).sorted()
        }

        item.isArchived = true
        #expect(planned(item).isEmpty)
        item.archivedAt = Fixtures.instant("2026-03-05T02:00:00Z")
        #expect(planned(item) == [Fixtures.date(2026, 3, 3), Fixtures.date(2026, 3, 4)])
    }

    /// R5: the graph, the week strip, and the summary do not count a planned dose of today before its time. At 12:00 only the
    /// morning dose counts, and at 06:00 nothing of today counts.
    @Test func theGraphTheWeekAndTheSummaryCountTheSameDoses() throws {
        let item = Fixtures.item()
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8), Fixtures.time(20)])
        let today = Fixtures.date(2026, 3, 7)
        let days = History.days([today], items: [item], schedules: [schedule], stored: [], deviceTimeZone: Fixtures.shanghai)

        for (now, planned) in [("2026-03-07T04:00:00Z", 1), ("2026-03-06T22:00:00Z", 0), ("2026-03-07T14:00:00Z", 2)] {
            let at = Fixtures.instant(now)
            let counts = History.counts(
                [today], items: [item], schedules: [schedule], stored: [], today: today, now: at, deviceTimeZone: Fixtures.shanghai
            )
            let summary = History.summary(days: days, today: today, now: at)[item.id]
            #expect(counts[today]?.scheduled ?? 0 == planned)
            #expect(summary?.planned ?? 0 == planned)
            #expect(summary?.noRecord ?? 0 == planned)
            let week = History.week(days: days, today: today, now: at).first
            #expect(week?.unrecordedDoses ?? 0 == planned)
        }
    }

    /// A dose that the user took back is "No record", and a skipped dose is not taken. As-needed doses have their own count.
    @Test func theSummaryCountsTakenSkippedNoRecordAndAsNeeded() throws {
        let item = Fixtures.item()
        let asNeededItem = Fixtures.item(name: "Ibuprofen")
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8), Fixtures.time(20)])
        let day = Fixtures.date(2026, 3, 5)
        func dose(_ slot: ScheduleSlotID, _ time: WallClockTime, _ actions: [IntakeAction]) throws -> HistoryDose {
            let occurrence = Occurrence(
                slotID: slot, plannedDate: day, plannedTime: time, timeZone: Fixtures.shanghai, scheduleVersionID: ScheduleVersionID()
            )
            var record = OccurrenceRecord(occurrenceID: occurrence.id)
            for action in actions { try record.record(Fixtures.event(for: occurrence, action, supersedes: record.events.last?.id)) }
            return HistoryDose(occurrence: occurrence, isStored: true, itemID: item.id, record: record)
        }
        let asNeeded = AsNeededOccurrence(
            id: OccurrenceID(), itemID: asNeededItem.id, plannedDate: day, plannedTime: Fixtures.time(13), timeZone: Fixtures.shanghai,
            dose: Dose("400 mg")
        )
        var asNeededRecord = OccurrenceRecord(occurrenceID: asNeeded.id)
        try asNeededRecord.record(IntakeEvent(occurrenceID: asNeeded.id, action: .taken, occurredAt: .now, recordedAt: .now, source: .app))
        let history = [
            HistoryDay(
                date: day,
                doses: [try dose(schedule.slots[0].id, Fixtures.time(8), [.taken]), try dose(schedule.slots[1].id, Fixtures.time(20), [.taken, .undo])],
                asNeeded: [HistoryAsNeededDose(occurrence: asNeeded, record: asNeededRecord)]
            ),
            HistoryDay(date: day.adding(days: -1), doses: [try dose(schedule.slots[0].id, Fixtures.time(8), [.skipped])]),
        ]

        let summary = History.summary(days: history, today: Fixtures.date(2026, 3, 7), now: Fixtures.instant("2026-03-07T04:00:00Z"))

        let planned = try #require(summary[item.id])
        #expect((planned.taken, planned.skipped, planned.noRecord, planned.planned) == (1, 1, 1, 3))
        #expect(summary[asNeededItem.id]?.asNeededTaken == 1)
        #expect(summary[asNeededItem.id]?.planned == 0)
    }

    /// An item with as-needed doses and later a plan keeps both counts, so no dose drops out of a summary.
    @Test func anItemWithAsNeededAndPlannedDosesCountsBoth() throws {
        let item = Fixtures.item()
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8)])
        let day = Fixtures.date(2026, 3, 5)
        let occurrence = Occurrence(
            slotID: schedule.slots[0].id, plannedDate: day, plannedTime: Fixtures.time(8), timeZone: Fixtures.shanghai,
            scheduleVersionID: ScheduleVersionID()
        )
        var planned = OccurrenceRecord(occurrenceID: occurrence.id)
        try planned.record(Fixtures.event(for: occurrence, .taken))
        var asNeeded: [HistoryAsNeededDose] = []
        for hour in [9, 13, 18] {
            let dose = AsNeededOccurrence(id: OccurrenceID(), itemID: item.id, plannedDate: day, plannedTime: Fixtures.time(hour), timeZone: Fixtures.shanghai)
            var record = OccurrenceRecord(occurrenceID: dose.id)
            try record.record(IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: .now, recordedAt: .now, source: .app))
            asNeeded.append(HistoryAsNeededDose(occurrence: dose, record: record))
        }
        let days = [HistoryDay(
            date: day, doses: [HistoryDose(occurrence: occurrence, isStored: true, itemID: item.id, record: planned)], asNeeded: asNeeded
        )]

        let summary = try #require(History.summary(days: days, today: Fixtures.date(2026, 3, 7), now: .now)[item.id])

        #expect((summary.planned, summary.taken, summary.asNeededTaken) == (1, 1, 3))
    }
}
