import Foundation
import Testing
@testable import MaruCore

@Suite("Week strip of the history page (D054)")
struct HistoryWeekTests {
    /// A twice-daily item with a taken day, a half-taken day, and a dose of today that is not due yet.
    /// An as-needed item with one taken dose.
    @Test func stripMarksEachDayAndLeavesOutADoseThatIsNotDueYet() throws {
        let item = Fixtures.item()
        let asNeededItem = Fixtures.item(name: "Ibuprofen")
        let schedule = Fixtures.schedule(itemID: item.id, times: [Fixtures.time(8), Fixtures.time(20)])
        let morning = schedule.slots[0].id
        let evening = schedule.slots[1].id
        func stored(_ slot: ScheduleSlotID, _ day: LocalDate, _ action: IntakeAction) throws -> StoredHistoryDose {
            let occurrence = Occurrence(
                slotID: slot, plannedDate: day, plannedTime: slot == morning ? Fixtures.time(8) : Fixtures.time(20),
                timeZone: Fixtures.shanghai, scheduleVersionID: ScheduleVersionID()
            )
            var record = OccurrenceRecord(occurrenceID: occurrence.id)
            try record.record(Fixtures.event(for: occurrence, action))
            return StoredHistoryDose(occurrence: occurrence, itemID: item.id, record: record)
        }
        let asNeeded = AsNeededOccurrence(
            id: OccurrenceID(), itemID: asNeededItem.id, plannedDate: Fixtures.date(2026, 3, 4), plannedTime: Fixtures.time(13),
            timeZone: Fixtures.shanghai
        )
        var asNeededRecord = OccurrenceRecord(occurrenceID: asNeeded.id)
        try asNeededRecord.record(
            IntakeEvent(
                occurrenceID: asNeeded.id, action: .taken, occurredAt: .now, recordedAt: .now, source: .app,
                supersedes: nil
            )
        )
        let today = Fixtures.date(2026, 3, 7)
        let days = History.days(
            (0..<7).map { today.adding(days: -$0) },
            items: [item, asNeededItem],
            schedules: [schedule],
            stored: [
                try stored(morning, Fixtures.date(2026, 3, 5), .taken),
                try stored(evening, Fixtures.date(2026, 3, 5), .taken),
                try stored(morning, Fixtures.date(2026, 3, 6), .taken),
                try stored(evening, Fixtures.date(2026, 3, 6), .skipped),
            ],
            asNeeded: [HistoryAsNeededDose(occurrence: asNeeded, record: asNeededRecord)],
            deviceTimeZone: Fixtures.shanghai
        )

        // 12:00 in Shanghai on the last day: the morning dose is due, the evening dose is not.
        let week = History.week(days: days, today: today, now: Fixtures.instant("2026-03-07T04:00:00Z"))

        let planned = try #require(week.first { $0.itemID == item.id })
        let expected: [HistoryDayMark] = [.missed, .missed, .missed, .missed, .all, .some, .missed]
        #expect(planned.marks == expected)
        #expect(planned.dayParts == [.morning, .evening])
        let single = try #require(week.first { $0.itemID == asNeededItem.id })
        let expectedSingle: [HistoryDayMark] = [.none, .none, .none, .all, .none, .none, .none]
        #expect(single.marks == expectedSingle)
        #expect(single.isAsNeeded)

        // At 06:00 in Shanghai nothing of today is due, so the strip shows no miss for today.
        let early = History.week(days: days, today: today, now: Fixtures.instant("2026-03-06T22:00:00Z"))
        #expect(try #require(early.first { $0.itemID == item.id }).marks.last == HistoryDayMark.none)
    }
}
