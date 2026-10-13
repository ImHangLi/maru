import Foundation
import Testing
@testable import MaruCore

@Suite("Stable slot IDs across edits (spec 7.1, 7.2, T16, T17)")
struct ScheduleTests {
    @Test func changingATimeKeepsTheSlotID() throws {
        var (schedule, morning, evening) = Fixtures.twiceDailySchedule()
        let slotsBefore = schedule.slots

        let edited = try schedule.changeTime(of: morning, to: Fixtures.time(9, 30), effectiveFrom: Fixtures.date(2026, 3, 1))

        #expect(schedule.slots == slotsBefore)
        #expect(edited.time(for: morning) == Fixtures.time(9, 30))
        #expect(edited.time(for: evening) == Fixtures.time(20))
        #expect(edited.slotTimes.map(\.slotID) == [morning, evening])
    }

    @Test func editAppendsAVersionAndKeepsOldVersionsUnchanged() throws {
        var (schedule, morning, _) = Fixtures.twiceDailySchedule()
        let original = try #require(schedule.versions.first)

        let edited = try schedule.changeTime(of: morning, to: Fixtures.time(9), effectiveFrom: Fixtures.date(2026, 3, 1))

        #expect(schedule.versions == [original, edited])
        #expect(schedule.version(on: Fixtures.date(2026, 2, 28)) == original)
        #expect(schedule.version(on: Fixtures.date(2026, 3, 1)) == edited)
        #expect(schedule.version(on: Fixtures.date(2025, 12, 31)) == nil)
    }

    @Test func editedVersionKeepsRuleDoseAndTimeZone() throws {
        let dose = try #require(Dose("500 μg"))
        var (schedule, morning, _) = Fixtures.twiceDailySchedule(dose: dose)
        let edited = try schedule.changeTime(of: morning, to: Fixtures.time(9), effectiveFrom: Fixtures.date(2026, 3, 1))
        #expect(edited.dose == dose)
        #expect(edited.weeklyRule == .everyDay)
        #expect(edited.timeZonePolicy == .fixed(Fixtures.shanghai))
    }

    @Test func aNewTimePointGetsItsOwnSlot() throws {
        var (schedule, morning, evening) = Fixtures.twiceDailySchedule()
        let noon = try schedule.addSlot().id
        let latest = try #require(schedule.versions.last)
        let next = try ScheduleVersion(
            scheduleID: schedule.id,
            effectiveFrom: Fixtures.date(2026, 3, 1),
            weeklyRule: latest.weeklyRule,
            slotTimes: latest.slotTimes + [SlotTime(slotID: noon, time: Fixtures.time(12))],
            timeZonePolicy: latest.timeZonePolicy
        )
        try schedule.appendVersion(next)
        #expect(Set([morning, evening, noon]).count == 3)
        #expect(schedule.slots.map(\.id) == [morning, evening, noon])
    }

    /// A save keeps the stored cycle only when its due dates from today on stay the same (D065, spec 2).
    @Test func aMovedFirstDayKeepsTheStoredCycleOnlyWithTheSameDueDates() {
        let today = Fixtures.date(2026, 10, 13)
        let past = Fixtures.cycle(from: Fixtures.date(2026, 10, 1), on: 3, off: 4)
        #expect(Fixtures.cycle(from: Fixtures.date(2026, 10, 8), on: 3, off: 4).hasSameDueDates(as: past, from: today))
        #expect(!Fixtures.cycle(from: Fixtures.date(2026, 10, 29), on: 3, off: 4).hasSameDueDates(as: past, from: today))
        // A future first day moved one cycle later drops the doses on October 20 to 22.
        let future = Fixtures.cycle(from: Fixtures.date(2026, 10, 20), on: 3, off: 4)
        #expect(!Fixtures.cycle(from: Fixtures.date(2026, 10, 27), on: 3, off: 4).hasSameDueDates(as: future, from: today))
    }

    @Test func versionRejectsDuplicateOrMissingSlots() {
        let slot = ScheduleSlotID()
        #expect(throws: ScheduleError.noSlotTimes) {
            try ScheduleVersion(
                scheduleID: ScheduleID(),
                effectiveFrom: Fixtures.date(2026, 1, 1),
                weeklyRule: .everyDay,
                slotTimes: [],
                timeZonePolicy: .followsDevice
            )
        }
        #expect(throws: ScheduleError.duplicateSlot(slot)) {
            try ScheduleVersion(
                scheduleID: ScheduleID(),
                effectiveFrom: Fixtures.date(2026, 1, 1),
                weeklyRule: .everyDay,
                slotTimes: [SlotTime(slotID: slot, time: Fixtures.time(8)), SlotTime(slotID: slot, time: Fixtures.time(9))],
                timeZonePolicy: .followsDevice
            )
        }
    }
}
