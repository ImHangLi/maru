import Foundation
import Testing
@testable import MaruCore

/// The iPhone had build 4 (version 1.0.0) on 2026-10-14 and gets version 1.1 later. The system still holds the requests
/// of the old build, with its identifiers and its old content. The first run of the new build must make all right (D086).
@Suite("App update")
struct AppUpdateTests {
    private func oldRequest(_ id: String, _ body: String, title: String, fire: Date) -> SimNotification {
        SimNotification(
            identifier: id, text: ReminderText(title: title, body: body),
            userInfo: ["seriesID": "series|device|21:00", "plannedDate": "2026-10-15"], hasTakenAction: false,
            threadIdentifier: nil, trigger: .instant(fire)
        )
    }

    @Test func oldFollowUpsAndAnUnconfirmedGlobalSettingAreMadeRight() async throws {
        let phone = try await Phone.make(start: "2026-10-14 12:00")
        try await phone.addItem("Coenzyme Q10", at: ["09:00", "21:00"])
        try await phone.addItem("Magnesium Glycinate", at: ["21:00"])
        try await phone.addItem("Fish Oil", at: ["21:00"])
        // Build 4 archived Fish Oil, and its run did not finish: the daily request still names it (see `KillSweepTests`).
        try await phone.archive("Fish Oil")
        phone.terminate()
        // Build 4 follow-ups of the old identifier form, one of them for the archived item.
        let fire = phone.instant("2026-10-15 21:30")
        await phone.center.inject(oldRequest("followup|device@Australia/Sydney|2026-10-15|21:00", "Magnesium Glycinate, and Fish Oil", title: "Still to take", fire: fire))
        await phone.center.inject(oldRequest("followup|device@Australia/Sydney|2026-10-15|21:00|2", "Fish Oil", title: "Still to take", fire: fire))
        await phone.center.inject(
            oldRequest("followup|device@Australia/Sydney|2026-10-14|21:00", "Fish Oil", title: "Still to take", fire: fire),
            delivered: phone.instant("2026-10-14 21:30")
        )
        // The 1.0 setting is on and its change is not confirmed. The update copies it to every item.
        try phone.store.adoptFollowUpSetting(FollowUpSetting(count: .untilRecorded, interval: .minutes15), changed: .distantFuture)
        for index in phone.truth.items.indices {
            phone.truth.items[index].followUp = FollowUpSetting(count: .untilRecorded, interval: .minutes15)
        }
        await phone.advance(to: "2026-10-15 08:00")
        await phone.foreground()
        await phone.expectCorrect("first run of the new build")
        await phone.foreground()
        await phone.expectCorrect("second run")
        let removed = await phone.center.removeLog
        #expect(removed.contains { $0.hasPrefix("followup|") })
    }
}
