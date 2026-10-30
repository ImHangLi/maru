import Foundation
import Testing
@testable import MaruCore

/// Keeps what each run creates and replans, as the database does.
private struct Shelf {
    var item = Fixtures.item()
    var stored: [OccurrenceKey: StoredOccurrence] = [:]

    @discardableResult
    mutating func run(
        _ schedule: Schedule,
        at now: String,
        device: NamedTimeZone = Fixtures.shanghai
    ) -> OccurrenceGeneration.Outcome {
        let generation = OccurrenceGeneration(now: Fixtures.instant(now), deviceTimeZone: device)
        let outcome = generation.outcome(items: [item], schedules: [schedule], stored: Array(stored.values))
        for occurrence in outcome.created + outcome.replanned {
            stored[occurrence.key] = StoredOccurrence(occurrence: occurrence, isRecorded: false)
        }
        return outcome
    }

    /// The occurrence now has a record.
    mutating func record(_ occurrence: Occurrence) {
        stored[occurrence.key] = StoredOccurrence(occurrence: occurrence, isRecorded: true)
    }
}

private extension Array where Element == Occurrence {
    func of(_ slotID: ScheduleSlotID, on date: LocalDate) -> [Occurrence] {
        filter { $0.slotID == slotID && $0.plannedDate == date }
    }
}

@Suite("Occurrence generation (spec 7.2, 8.5, T25)")
struct OccurrenceGenerationTests {
    // 1 March 2026 is a Sunday. The schedule of the fixture has 08:00 and 20:00 in Shanghai, which is UTC+8.
    let today = Fixtures.date(2026, 3, 1)
    let tomorrow = Fixtures.date(2026, 3, 2)
    /// 07:00 and 12:00 on 1 March in Shanghai.
    let early = "2026-02-28T23:00:00Z"
    let noon = "2026-03-01T04:00:00Z"

    // MARK: A schedule change in the middle of a day

    @Test func recordedOccurrenceStaysWhenThePlanDropsItsSlot() throws {
        var shelf = Shelf()
        var schedule = Fixtures.schedule(itemID: shelf.item.id, times: [Fixtures.time(8), Fixtures.time(20)])
        let (morning, evening) = (schedule.slots[0].id, schedule.slots[1].id)
        let before = shelf.run(schedule, at: early).occurrences
        let taken = try #require(before.of(morning, on: today).first)
        shelf.record(taken)

        // From today the schedule has only the evening.
        try schedule.appendVersion(
            ScheduleVersion(
                scheduleID: schedule.id,
                effectiveFrom: today,
                weeklyRule: .everyDay,
                slotTimes: [SlotTime(slotID: evening, time: Fixtures.time(20))],
                timeZonePolicy: .fixed(Fixtures.shanghai)
            )
        )
        let outcome = shelf.run(schedule, at: noon)

        #expect(outcome.occurrences.of(morning, on: today) == [taken])
        // The morning of tomorrow has no record. It is not planned now, and nothing removes or changes its row.
        #expect(outcome.occurrences.of(morning, on: tomorrow).isEmpty)
        #expect(outcome.replanned.allSatisfy { $0.slotID == evening })
        #expect(shelf.stored.count == 6)
        // An archived item keeps the record of today in the same way.
        shelf.item.isArchived = true
        #expect(shelf.run(schedule, at: noon).occurrences == [taken])
    }

    // MARK: Clock changes (T25)

    @Test func localTimeThatTheClockSkipsGivesOneFlaggedOccurrence() throws {
        var shelf = Shelf()
        // 02:30 does not come on 8 March 2026 in New York.
        let skipped = Fixtures.schedule(itemID: shelf.item.id, times: [Fixtures.time(2, 30)], timeZonePolicy: .fixed(Fixtures.newYork))
        let spring = shelf.run(skipped, at: "2026-03-08T16:00:00Z", device: Fixtures.newYork).occurrences
        #expect(spring.map(\.plannedDate) == [Fixtures.date(2026, 3, 7), Fixtures.date(2026, 3, 8), Fixtures.date(2026, 3, 9)])
        #expect(spring.map(\.resolvedTime.needsReview) == [false, true, false])
        #expect(spring[1].resolvedTime == .nonexistent(firstValidAfter: Fixtures.instant("2026-03-08T07:00:00Z")))
        // The plan keeps the time that the user confirmed.
        #expect(spring.map(\.plannedTime) == Array(repeating: Fixtures.time(2, 30), count: 3))
        #expect(spring.map(\.timeZone) == Array(repeating: Fixtures.newYork, count: 3))
    }

    @Test func localTimeThatComesTwoTimesGivesOneFlaggedOccurrence() throws {
        var shelf = Shelf()
        // 01:30 comes two times on 1 November 2026 in New York. It is still one occurrence.
        let repeated = Fixtures.schedule(itemID: shelf.item.id, times: [Fixtures.time(1, 30)], timeZonePolicy: .fixed(Fixtures.newYork))
        let autumn = shelf.run(repeated, at: "2026-11-01T16:00:00Z", device: Fixtures.newYork).occurrences
        #expect(autumn.map(\.plannedDate) == [Fixtures.date(2026, 10, 31), Fixtures.date(2026, 11, 1), Fixtures.date(2026, 11, 2)])
        #expect(autumn.map(\.resolvedTime.needsReview) == [false, true, false])
        #expect(
            autumn[1].resolvedTime
                == .repeated(first: Fixtures.instant("2026-11-01T05:30:00Z"), second: Fixtures.instant("2026-11-01T06:30:00Z"))
        )
        #expect(shelf.run(repeated, at: "2026-11-01T16:00:00Z", device: Fixtures.newYork).created.isEmpty)
    }

    /// Every second day counts calendar dates, so a day of 23 or 25 hours does not move the rhythm (D036).
    @Test func everyOtherDayKeepsItsRhythmAcrossAClockChange() {
        var shelf = Shelf()
        // In New York, 8 March 2026 has 23 hours, and 1 November 2026 has 25 hours.
        for (start, days) in [(Fixtures.date(2026, 3, 5), [5, 7, 9, 11]), (Fixtures.date(2026, 10, 30), [30, 32, 34, 36])] {
            let plan = Fixtures.schedule(
                itemID: shelf.item.id, times: [Fixtures.time(8)], dayCycle: Fixtures.cycle(from: start), timeZonePolicy: .fixed(Fixtures.newYork)
            )
            let first = start.adding(days: -start.day)
            let due = (start.day - 2...start.day + 7).filter {
                !plan.plannedOccurrences(on: first.adding(days: $0), deviceTimeZone: Fixtures.shanghai).isEmpty
            }
            #expect(due == days)
        }
        // On a day with no dose, the window has the dose of the day before and of the day after, and none of today.
        let plan = Fixtures.schedule(
            itemID: shelf.item.id, times: [Fixtures.time(8)], dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 5)),
            timeZonePolicy: .fixed(Fixtures.newYork)
        )
        #expect(
            shelf.run(plan, at: "2026-03-08T16:00:00Z", device: Fixtures.newYork).occurrences.map(\.plannedDate)
                == [Fixtures.date(2026, 3, 7), Fixtures.date(2026, 3, 9)]
        )
    }

    /// A cycle has a dose on its days on and none in its pause. It counts calendar dates, so a day of
    /// 23 hours does not move it (D065, T52).
    @Test func cycleHasNoDoseInItsPauseAndKeepsItsRhythmAcrossAClockChange() {
        var shelf = Shelf()
        // 3 days on and 2 days off from 5 March in New York, where 8 March 2026 has 23 hours.
        let plan = Fixtures.schedule(
            itemID: shelf.item.id, times: [Fixtures.time(8)],
            dayCycle: Fixtures.cycle(from: Fixtures.date(2026, 3, 5), on: 3, off: 2), timeZonePolicy: .fixed(Fixtures.newYork)
        )
        let due = (3...16).filter {
            !plan.plannedOccurrences(on: Fixtures.date(2026, 3, $0), deviceTimeZone: Fixtures.shanghai).isEmpty
        }
        #expect(due == [5, 6, 7, 10, 11, 12, 15, 16])
        // On the first day of the pause, the window has only the dose of the day before. On the last day of
        // the pause, it has only the dose of the day after.
        #expect(
            shelf.run(plan, at: "2026-03-08T16:00:00Z", device: Fixtures.newYork).occurrences.map(\.plannedDate)
                == [Fixtures.date(2026, 3, 7)]
        )
        #expect(
            shelf.run(plan, at: "2026-03-09T16:00:00Z", device: Fixtures.newYork).occurrences.map(\.plannedDate)
                == [Fixtures.date(2026, 3, 10)]
        )
    }

    @Test func zoneWithNoClockChangeGivesOneOccurrenceWithNoFlag() throws {
        var shelf = Shelf()
        // Shanghai has no clock change, so nothing is flagged.
        let plain = Fixtures.schedule(itemID: shelf.item.id, times: [Fixtures.time(2, 30)])
        let occurrences = shelf.run(plain, at: "2026-03-08T04:00:00Z").occurrences
        #expect(occurrences.map(\.plannedDate) == [Fixtures.date(2026, 3, 7), Fixtures.date(2026, 3, 8), Fixtures.date(2026, 3, 9)])
        #expect(occurrences.map(\.resolvedTime.needsReview) == [false, false, false])
        // A fixed zone keeps its own dates when the device is on the other side of the date line.
        // At this instant it is 3 March in Kiritimati and 1 March in Pago Pago.
        let far = try Fixtures.schedule(
            itemID: shelf.item.id,
            times: [Fixtures.time(8)],
            timeZonePolicy: .fixed(NamedTimeZone(identifier: "Pacific/Kiritimati"))
        )
        let device = try NamedTimeZone(identifier: "Pacific/Pago_Pago")
        #expect(
            shelf.run(far, at: "2026-03-02T10:30:00Z", device: device).occurrences.map(\.plannedDate)
                == [Fixtures.date(2026, 3, 2), Fixtures.date(2026, 3, 3), Fixtures.date(2026, 3, 4)]
        )
    }
}
