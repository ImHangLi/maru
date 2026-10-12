import Foundation
import Testing
@testable import MaruCore

@Suite("Analytics allowlist and consent (spec 11, D051, T41, T45)")
struct AnalyticsTests {
    @Test func theAllowlistRejectsWhatItDoesNotName() throws {
        #expect(throws: AnalyticsEvent.Rejection.unknownEvent("item_added")) {
            try AnalyticsEvent(name: "item_added")
        }
        // A name, a dose, or a time can not ride along in a known event (T45).
        #expect(throws: AnalyticsEvent.Rejection.unknownField(event: "setup_step", field: "item_name")) {
            try AnalyticsEvent(name: "setup_step", properties: ["step": .text("item_saved"), "item_name": .text("Zinc")])
        }
        // A free text where the schema has a choice.
        #expect(throws: AnalyticsEvent.Rejection.invalidValue(event: "core_error", field: "code")) {
            try AnalyticsEvent(name: "core_error", properties: ["code": .text("SQLITE_CORRUPT at /var/mobile/db")])
        }
        // Each event that the app builds passes the same check.
        let built: [AnalyticsEvent] = [
            .itemSaved,
            .dailyUsage(dayIndex: 4, used: [.record, .widget]),
            .coreError(.save, .newerSchema),
            .feedbackOpened,
        ]
        for event in built {
            #expect(try AnalyticsEvent(name: event.name, properties: event.properties) == event)
        }
    }

    @Test func consentFollowsTheRegionAndWaitsForTheNotice() throws {
        let suite = "analytics-consent-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        // The EU, the UK, Switzerland, and an unknown region: off until the user opts in (T41).
        for region in ["DE", "GB", "CH", "NO", nil] {
            let preference = AnalyticsPreference(defaults: defaults, regionCode: region)
            #expect(!preference.isActive)
            preference.markNoticeShown()
            #expect(!preference.isActive)
        }
        defaults.removePersistentDomain(forName: suite)

        // Elsewhere: on by default, but only after the notice showed.
        let preference = AnalyticsPreference(defaults: defaults, regionCode: "US")
        #expect(preference.isOn && !preference.isActive && preference.needsNotice)
        preference.markNoticeShown()
        #expect(preference.isActive && !preference.needsNotice)
        preference.set(false)
        #expect(!preference.isActive && !preference.isOn)

        let optIn = AnalyticsPreference(defaults: defaults, regionCode: "FR")
        optIn.set(true)
        #expect(optIn.isActive)
    }
}
