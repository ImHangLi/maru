import Foundation
import Testing
@testable import MaruCore

private struct ReadFailure: Error {}

/// The saved plan and the notification system of a test. It keeps one request for each identifier, as the system does.
private actor Phone: ReminderPlanSource, ReminderCenter, ReminderPrivacyStore {
    var items: [Item] = []
    var schedules: [Schedule] = []
    var status = ReminderAuthorization.authorized
    /// What the user answers to the permission prompt.
    var answer = ReminderAuthorization.denied
    var planReadFails = false
    /// The system takes a request with no error and does not keep it.
    var dropsRequests = false
    /// The system removes a request after this number of reads of the pending requests, and not in the call.
    var readsBeforeRemoval = 0
    var pending: [String: [String: String]] = [:]
    /// The text of each pending request.
    private(set) var texts: [String: ReminderText] = [:]
    /// The pending requests with the "Taken" action.
    /// The category that the system holds for each request. A request that is not here has no known category (D090).
    var categories: [String: ReminderCategory] = [:]
    private var openRemovals: [(identifiers: [String], readsLeft: Int)] = []
    private(set) var prompts = 0
    private(set) var added: [String] = []
    /// The most pending requests after an add. Over `ReminderPlan.systemLimit`, the system can drop one.
    private(set) var peak = 0
    /// The plan read and the removal of each run, in the order of the calls.
    private(set) var steps: [String] = []

    /// Saves an item with one schedule.
    @discardableResult
    func save(times: [Int]) -> Schedule {
        let item = Fixtures.item()
        items.append(item)
        let schedule = Fixtures.schedule(itemID: item.id, times: times.map { Fixtures.time($0) })
        schedules.append(schedule)
        return schedule
    }

    func update(_ change: @Sendable (isolated Phone) throws -> Void) rethrows {
        try change(self)
    }

    func reminderPlan(at now: Date, deviceTimeZone: NamedTimeZone, privacy: ReminderPrivacy, alarms: AlarmCover) throws -> ReminderPlan {
        steps.append("plan")
        guard !planReadFails else { throw ReadFailure() }
        return ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: deviceTimeZone, privacy: privacy)
    }

    nonisolated func load() -> ReminderPrivacy { .showNames }
    nonisolated func save(_ privacy: ReminderPrivacy) {}
    nonisolated func text(for content: ReminderContent) -> ReminderText { Fixtures.text(for: content) }

    func authorization() -> ReminderAuthorization {
        status
    }

    func requestAuthorization() -> ReminderAuthorization {
        prompts += 1
        status = answer
        return status
    }

    func pendingRequests() -> [PendingReminder] {
        steps.append("read")
        let read = pending.map {
            PendingReminder(
                identifier: $0.key, userInfo: $0.value, text: texts[$0.key],
                presentation: categories[$0.key].map { ReminderPresentation(category: $0) }
            )
        }
        openRemovals = openRemovals.map { ($0.identifiers, $0.readsLeft - 1) }
        openRemovals.filter { $0.readsLeft == 0 }.flatMap(\.identifiers).forEach { pending[$0] = nil }
        openRemovals.removeAll { $0.readsLeft == 0 }
        return read
    }

    func add(_ request: ReminderRequest) {
        added.append(RequestGeneration.base(of: request.identifier))
        if !dropsRequests {
            pending[RequestGeneration.base(of: request.identifier)] = request.userInfo
            texts[RequestGeneration.base(of: request.identifier)] = text(for: request.content)
            categories[RequestGeneration.base(of: request.identifier)] = request.content.category
        }
        peak = max(peak, pending.count)
    }

    func remove(identifiers: [String]) {
        steps.append("remove")
        if readsBeforeRemoval > 0 {
            openRemovals.append((identifiers, readsBeforeRemoval))
        } else {
            identifiers.forEach { pending[$0] = nil }
        }
    }
}

@Suite("Reminder reconciliation (spec 2.2, 8.1, 8.5, T07, T08, T13, T14)")
struct ReminderEngineTests {
    private let phone = Phone()
    private let engine: ReminderEngine

    init() {
        engine = ReminderEngine(source: phone, center: phone, privacy: phone)
    }

    /// A run on 2 March 2026 in Shanghai.
    private func reconcile(on engine: ReminderEngine? = nil, mayAskForPermission: Bool = false) async throws -> ReminderOutcome {
        try await (engine ?? self.engine).reconcile(
            at: Fixtures.instant("2026-03-02T00:00:00Z"),
            deviceTimeZone: Fixtures.shanghai,
            mayAskForPermission: mayAskForPermission
        )
    }

    @Test func secondRunAddsNothingAndRunsDoNotOverlap() async throws {
        let schedule = await phone.save(times: [8, 20])
        let first = try await reconcile()
        #expect(first.schedules == [schedule.id: .scheduled])
        let pending = await phone.pending
        #expect(Set(pending.keys) == ["series|Asia/Shanghai|08:00|daily", "series|Asia/Shanghai|20:00|daily"])

        // Runs at the same time, for example from a launch and from a save.
        try await withThrowingTaskGroup(of: ReminderOutcome.self) { group in
            for _ in 0..<10 {
                group.addTask { try await reconcile() }
            }
            for try await outcome in group {
                #expect(outcome == first)
            }
        }
        #expect(await phone.pending == pending)
        #expect(await phone.added.count == 2)
        // Each run reads the plan and makes its changes before the next run reads the plan.
        // A run reads the pending requests after its plan and before the next run reads the plan.
        let steps = await phone.steps
        #expect(steps.filter { $0 == "plan" }.count == 11)
        #expect(!zip(steps, steps.dropFirst()).contains { $0 == "plan" && $1 == "plan" })
    }

    @Test func editOfATimeMovesTheRequestAndKeepsTheRequestsOfOthers() async throws {
        var schedule = await phone.save(times: [8, 20])
        // A request that is not a series request, for example a one-time reminder of a later feature.
        await phone.update { $0.pending["once|1"] = [:] }
        _ = try await reconcile()

        try schedule.changeTime(of: schedule.slots[0].id, to: Fixtures.time(9), effectiveFrom: Fixtures.date(2026, 3, 1))
        await phone.update { [schedule] in $0.schedules = [schedule] }
        let outcome = try await reconcile()

        #expect(outcome.schedules == [schedule.id: .scheduled])
        #expect(
            Set(await phone.pending.keys)
                == ["series|Asia/Shanghai|09:00|daily", "series|Asia/Shanghai|20:00|daily", "once|1"]
        )
        // The evening request has the new schedule version, so it is the request of the plan of now.
        let plan = try await phone.reminderPlan(
            at: Fixtures.instant("2026-03-02T00:00:00Z"), deviceTimeZone: Fixtures.shanghai, privacy: .showNames, alarms: .none
        )
        #expect(await phone.pending["series|Asia/Shanghai|20:00|daily"] == plan.requests[1].userInfo)
    }

    @Test func renameReplacesOnlyTheRequestThatNamesTheItem() async throws {
        await phone.save(times: [8])
        await phone.save(times: [20])
        _ = try await reconcile()
        let before = await phone.added.count

        // A repeating request keeps the text that it got when it was added (D029). The revision does not change.
        try await phone.update { try $0.items[0].rename("Zinc") }
        let outcome = try await reconcile()

        #expect(outcome.schedules.values.allSatisfy { $0 == .scheduled })
        #expect(await phone.added.dropFirst(before) == ["series|Asia/Shanghai|08:00|daily"])
        #expect(await phone.texts["series|Asia/Shanghai|08:00|daily"]?.body == "Zinc")
        // The new text is current, so the next run adds nothing.
        _ = try await reconcile()
        #expect(await phone.added.count == before + 1)
    }

    @Test func requestWithoutAKnownCategoryIsReplacedAndTakesNoNewRoom() async throws {
        await phone.save(times: [8])
        _ = try await reconcile()
        let before = await phone.added.count
        #expect(await phone.categories == ["series|Asia/Shanghai|08:00|daily": .single])

        // A request from before the action has the same identifier, `userInfo`, and text, and no known category (D034, D090).
        await phone.update { $0.categories = [:] }
        let outcome = try await reconcile()

        #expect(outcome.schedules.values.allSatisfy { $0 == .scheduled })
        #expect(await phone.added.dropFirst(before) == ["series|Asia/Shanghai|08:00|daily"])
        #expect(await phone.categories == ["series|Asia/Shanghai|08:00|daily": .single])
        #expect(await phone.pending.count == 1)
        // The request is current now, so the next run adds nothing.
        _ = try await reconcile()
        #expect(await phone.added.count == before + 1)
    }

    @Test func movedTimeNextToFollowUpsStaysWithinTheSystemLimit() async throws {
        let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let item = Fixtures.item()
        var schedule = Fixtures.schedule(
            itemID: item.id, times: (8...15).map { Fixtures.time($0) }, weeklyRule: try WeeklyRule(weekdays: weekdays)
        )
        await phone.update { [schedule] in
            $0.items = [item]
            $0.schedules = [schedule]
        }
        _ = try await reconcile()
        #expect(await phone.pending.count == ReminderPlan.requestBudget)
        // The follow-up engine fills the rest of the system limit.
        await phone.update {
            for day in 1...16 {
                $0.pending[String(format: "followup|Asia/Shanghai|2026-03-%02d|08:00", day)] = [
                    FollowUpRequest.fireTimeKey: String(format: "2026-03-%02dT00:30:00Z", day)
                ]
            }
        }

        try schedule.changeTime(of: schedule.slots[0].id, to: Fixtures.time(7), effectiveFrom: Fixtures.date(2026, 3, 1))
        await phone.update { [schedule] in $0.schedules = [schedule] }
        let outcome = try await reconcile()

        #expect(outcome.schedules == [schedule.id: .scheduled])
        #expect(await phone.peak <= ReminderPlan.systemLimit)
    }

    @Test func movedTimesWithASlowRemovalWaitForRoom() async throws {
        let item = Fixtures.item()
        var schedule = Fixtures.schedule(
            itemID: item.id, times: (8...15).map { Fixtures.time($0) },
            weeklyRule: try WeeklyRule(weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
        )
        await phone.update { [schedule] in
            $0.items = [item]
            $0.schedules = [schedule]
        }
        _ = try await reconcile()

        // All 48 requests get new identifiers, and the removal of the old ones takes longer than the run reads.
        for (index, slot) in schedule.slots.enumerated() {
            try schedule.changeTime(of: slot.id, to: Fixtures.time(16 + index), effectiveFrom: Fixtures.date(2026, 3, 1))
        }
        await phone.update { [schedule] in
            $0.schedules = [schedule]
            $0.readsBeforeRemoval = 15
        }
        #expect(try await reconcile().schedules == [schedule.id: .removalPending])
        #expect(await phone.peak <= ReminderPlan.systemLimit)

        // The next run adds the rest.
        #expect(try await reconcile().schedules == [schedule.id: .scheduled])
        #expect(await phone.pending.count == ReminderPlan.requestBudget)
    }

    @Test func pausedScheduleAndArchivedItemHaveNoRequest() async throws {
        let paused = await phone.save(times: [8])
        let archived = await phone.save(times: [20])
        _ = try await reconcile()
        #expect(await phone.pending.count == 2)

        // T07: the reminders of one schedule are off.
        await phone.update { $0.schedules[0].isEnabled = false }
        var outcome = try await reconcile()
        #expect(outcome.schedules == [paused.id: .off, archived.id: .scheduled])
        #expect(Set(await phone.pending.keys) == ["series|Asia/Shanghai|20:00|daily"])

        // T08: the item is archived. The removal also runs while notifications are off for the app.
        await phone.update {
            $0.items[1].isArchived = true
            $0.status = .denied
        }
        outcome = try await reconcile()
        #expect(outcome.schedules == [paused.id: .off, archived.id: .off])
        #expect(await phone.pending.isEmpty)
    }

    @Test func removalThatTheSystemMakesLateDoesNotTakeTheRequestOfTheNextRun() async throws {
        let schedule = await phone.save(times: [8])
        _ = try await reconcile()

        // T07: the reminders are off. The system still holds the request when the removal call returns.
        await phone.update {
            $0.readsBeforeRemoval = 3
            $0.schedules[0].isEnabled = false
        }
        let paused = try await reconcile()
        // The run ends after the request is gone, so "off" is true.
        #expect(paused.schedules == [schedule.id: .off])
        #expect(await phone.pending.isEmpty)

        // The user turns the reminders on again at once. No late removal takes the new request.
        await phone.update { $0.schedules[0].isEnabled = true }
        let enabled = try await reconcile()
        for _ in 0..<3 { _ = await phone.pendingRequests() }
        #expect(enabled.schedules == [schedule.id: .scheduled])
        #expect(Set(await phone.pending.keys) == ["series|Asia/Shanghai|08:00|daily"])
    }

    @Test func requestThatTheSystemDoesNotKeepIsReportedAndTheNextRunAddsIt() async throws {
        let schedule = await phone.save(times: [8])
        await phone.update { $0.dropsRequests = true }

        // The plan is saved, and the reminder is not set.
        let failed = try await reconcile()
        #expect(failed.schedules == [schedule.id: .notSet(.notRegistered)])

        await phone.update { $0.dropsRequests = false }
        let retried = try await reconcile()
        #expect(retried.schedules == [schedule.id: .scheduled])
        #expect(await phone.pending.count == 1)
    }

    @Test func permissionPromptComesOnlyAfterTheFirstReminderAndADenialAddsNoRequest() async throws {
        await phone.update { $0.status = .notDetermined }

        // A save with no reminder does not ask, and a launch does not ask.
        _ = try await reconcile(mayAskForPermission: true)
        let schedule = await phone.save(times: [8])
        let launch = try await reconcile()
        #expect(await phone.prompts == 0)
        #expect(launch.schedules == [schedule.id: .notSet(.permissionNotAsked)])

        // The user confirms the first reminder and answers no (T13). The plan stays, and the state says why.
        let denied = try await reconcile(mayAskForPermission: true)
        #expect(await phone.prompts == 1)
        #expect(denied.authorization == .denied)
        #expect(denied.schedules == [schedule.id: .notSet(.permissionDenied)])
        #expect(await phone.pending.isEmpty)

        // The next save does not ask again.
        _ = try await reconcile(mayAskForPermission: true)
        #expect(await phone.prompts == 1)
    }

    @Test func planThatCannotBeReadRemovesNoRequest() async throws {
        let schedule = await phone.save(times: [8])
        _ = try await reconcile()
        let pending = await phone.pending

        // For example the database of a locked device. It is not an empty plan.
        await phone.update { $0.planReadFails = true }
        await #expect(throws: ReadFailure.self) {
            try await reconcile()
        }
        #expect(await phone.pending == pending)

        await phone.update { $0.planReadFails = false }
        #expect(try await reconcile().schedules == [schedule.id: .scheduled])
    }
}
