import Foundation
import MaruCore
import Testing
@testable import MaruDatabase

/// D088: one stored row that breaks a rule does not stop the others. Today, the history, and the reminders read the rest.
@Suite struct FaultIsolationTests {
    /// The root cause of the reports from the iPhone (D088): a taken as-needed dose has an occurrence with no slot and a
    /// state row. The reminder plan read the slot of every closed occurrence as a required value, so one such dose in the
    /// window of the plan made every reminder run fail with `invalidData`.
    @Test func anAsNeededRecordDoesNotStopTheReminderPlan() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let good = try await store.seed()
        let asNeeded = try Item(category: .medication, name: "Ibuprofen", form: .tablet, color: .orange)
        try await store.save(asNeeded)
        let now = Fixtures.instant("2026-03-01T06:30:00Z")
        let dose = AsNeededOccurrence(itemID: asNeeded.id, at: now, in: Fixtures.shanghai)
        let taken = IntakeEvent(occurrenceID: dose.id, action: .taken, occurredAt: now, recordedAt: now, source: .app)
        try await store.recordAsNeeded(taken, occurrence: dose)

        let plan = try await store.reminderPlan(at: now, deviceTimeZone: Fixtures.shanghai, privacy: .showNames)
        #expect(plan.needs[good.schedule.id] != nil)
        _ = try await store.followUpPlan(privacy: .showNames, at: now, deviceTimeZone: Fixtures.shanghai, alarms: .none)
    }

    @Test func aBadScheduleIsSkippedOnlyByTheReminderPlan() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let good = try await store.seed()
        let bad = try Item(category: .supplement, name: "Bad", form: .capsule, color: .blue)
        try await store.save(bad)
        let (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: bad.id)
        try await store.save(schedule)
        // A version that starts before the version before it: the shape that an old build could leave. It does not load.
        let version = UUID().uuidString
        try await store.execute(
            """
            INSERT INTO scheduleVersion (id, scheduleID, position, effectiveFrom, weekdays, dose, timeZonePolicy, timeZone)
            VALUES (?, ?, 1, '2025-01-01', '1234567', NULL, 'followsDevice', NULL)
            """,
            [version, schedule.id.text]
        )
        try await store.execute(
            "INSERT INTO scheduleVersionSlot (scheduleVersionID, slotID, position, time) VALUES (?, ?, 0, '08:00')",
            [version, morning.text]
        )
        _ = LocalStore.takeSkippedRules()
        await #expect(throws: StorageError.invalidData) { try await store.schedule(id: schedule.id) }

        // The reminder plan skips the schedule, names it, and keeps the others.
        let now = Fixtures.instant("2026-03-01T01:00:00Z")
        let plan = try await store.reminderPlan(at: now, deviceTimeZone: Fixtures.shanghai, privacy: .showNames)
        #expect(plan.needs[good.schedule.id] != nil)
        #expect(plan.needs[schedule.id] == .blocked(.unreadable))
        #expect(plan.unreadable == [schedule.id])
        #expect(LocalStore.takeSkippedRules() == [.versionOrder])
        // Today, the history, and every write keep the strict load: the damage shows and nothing is hidden (spec 7.3).
        await #expect(throws: StorageError.invalidData) { try await store.generateOccurrences(at: now, deviceTimeZone: Fixtures.shanghai) }
    }

    /// N7 (D089): one occurrence row that does not decode stopped the whole plan with `invalidData`. Now the plan skips the
    /// row, names the rule, and marks only the schedule of the row. The others plan as before.
    @Test func aBadOccurrenceRowDoesNotStopTheReminderPlans() async throws {
        let directory = TestDirectory()
        let store = try LocalStore(directory: directory.url)
        let good = try await store.seed()
        let other = try Item(category: .supplement, name: "Other", form: .capsule, color: .blue)
        try await store.save(other)
        let (schedule, morning, _) = Fixtures.twiceDailySchedule(itemID: other.id)
        try await store.save(schedule)
        // An occurrence of the second item with a time zone that no zone has.
        try await store.execute(
            """
            INSERT INTO occurrence (id, slotID, plannedDate, plannedTime, timeZone, scheduleVersionID)
            VALUES (?, ?, '2026-03-01', '08:00', 'Nowhere/Land', ?)
            """,
            [UUID().uuidString, morning.text, schedule.versions[0].id.text]
        )
        _ = LocalStore.takeSkippedRules()
        let now = Fixtures.instant("2026-03-01T01:00:00Z")
        let plan = try await store.followUpPlan(privacy: .showNames, at: now, deviceTimeZone: Fixtures.shanghai, alarms: .none)
        #expect(plan.hasUnreadable)
        let alarms = try await store.alarmPlan(privacy: .showNames, at: now, deviceTimeZone: Fixtures.shanghai, alarms: .none)
        #expect(alarms.hasUnreadable)
        let reminders = try await store.reminderPlan(at: now, deviceTimeZone: Fixtures.shanghai, privacy: .showNames)
        #expect(reminders.needs[good.schedule.id] != nil)
        // Today keeps the strict load (spec 7.3).
        await #expect(throws: StorageError.invalidData) { try await store.generateOccurrences(at: now, deviceTimeZone: Fixtures.shanghai) }
    }
}
