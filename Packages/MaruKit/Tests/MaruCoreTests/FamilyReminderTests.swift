import Foundation
import Testing
@testable import MaruCore

@Suite("Family reminders (D123, T57, T60, T61)")
struct FamilyReminderTests {
    private func request(owners: [PersonID], family: Family) throws -> ReminderRequest {
        let items = try owners.enumerated().map { index, owner in
            try Item(personID: owner, category: .supplement, name: "Item \(index)", form: .capsule, color: .pink)
        }
        let schedules = items.map { Fixtures.schedule(itemID: $0.id, times: [Fixtures.time(9)]) }
        let plan = ReminderPlan(
            items: items, schedules: schedules, now: Fixtures.instant("2026-03-02T00:00:00Z"),
            deviceTimeZone: Fixtures.shanghai, family: family
        )
        return try #require(plan.requests.first)
    }

    /// Two doses of one member at one time keep the group action. Doses of two members have none, and the text names each owner.
    @Test func aRequestForTwoMembersHasNoGroupAction() throws {
        let mom = try Person(kind: .person, name: "Mom")
        let me = try Person(kind: .me, name: nil)
        let family = Family(people: [me, mom])

        let oneMember = try request(owners: [me.id, me.id], family: family)
        #expect(oneMember.content.category == .group)

        let twoMembers = try request(owners: [me.id, mom.id], family: family)
        #expect(twoMembers.content.category == .snooze)
        #expect(twoMembers.content.names == [ReminderName(item: "Item 0", owner: .me), ReminderName(item: "Item 1", owner: .named("Mom"))])

        // A follow-up names only its own subset, even when another member shares the original time (T70).
        var item = try Item(personID: me.id, category: .supplement, name: "Vitamin D", form: .capsule, color: .pink)
        item.followUp = FollowUpSetting(count: .one, interval: .minutes10)
        let other = try Item(personID: mom.id, category: .medication, name: "Medicine", form: .tablet, color: .blue)
        let items = [item, other]
        let schedules = items.map { Fixtures.schedule(itemID: $0.id, times: [Fixtures.time(9)]) }
        let now = Fixtures.instant("2026-03-02T00:00:00Z")
        let plan = ReminderPlan(items: items, schedules: schedules, now: now, deviceTimeZone: Fixtures.shanghai, family: family)
        let followUps = FollowUpPlan(
            reminders: plan, items: items, schedules: schedules, stored: [], closed: [], now: now,
            deviceTimeZone: Fixtures.shanghai, family: family
        )
        let followUp = try #require(followUps.requests.first)
        #expect(followUp.content.category == .single)
        let delivered = DeliveredReminder(deliveredAt: followUp.fireDate, userInfo: followUp.userInfo, triggerWeekday: nil)
        let action = ReminderTapResolver(now: followUp.fireDate, deviceTimeZone: Fixtures.shanghai, observedTimeZone: nil)
            .actionDoses(of: delivered, items: items, schedules: schedules)
        #expect(action.doses.map(\.slotID) == schedules[0].slots.map(\.id))
        let hidden = ReminderPlan(
            items: items, schedules: schedules, now: now, deviceTimeZone: Fixtures.shanghai, privacy: .hideNames, family: family
        )
        #expect(hidden.requests.allSatisfy { $0.content.names == nil && $0.content.category == .snooze })

        // With one active member the text is the text of today (T57).
        let alone = try request(owners: [me.id, me.id], family: Family(people: [me]))
        #expect(alone.content.names == ["Item 0", "Item 1"])
        #expect(alone.content.category == .group)
    }
}
