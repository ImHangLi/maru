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
        for field in ["person_name", "person_id", "person_kind", "used_family_switcher"] {
            #expect(throws: AnalyticsEvent.Rejection.unknownField(event: "daily_usage_summary", field: field)) {
                try AnalyticsEvent(name: "daily_usage_summary", properties: [field: .text("private")])
            }
        }
        for (size, bucket) in [(1, "1"), (2, "2"), (8, "3_plus")] {
            #expect(AnalyticsEvent.dailyUsage(dayIndex: 0, .init(familySize: size)).properties["family_size"] == .text(bucket))
        }
        // Each event that the app builds passes the same check.
        let built: [AnalyticsEvent] = [
            .setupStep(.editorOpened, mode: .new),
            .itemSaved(AnalyticsEvent.ItemSetup(
                mode: .replace, hasReminder: true, hasAlarm: true, hasFollowUp: false, hasAmount: true, hasNote: false,
                hasPhoto: true, nameSource: .scan, usedCompletion: true, isFirstItem: false, duration: 95
            )),
            .editorClosed(mode: .edit, hadChanges: true, duration: 400),
            .dailyUsage(dayIndex: 4, AnalyticsEvent.UsageDay(used: Set(AnalyticsEvent.UsageFlag.allCases), opens: 9, activeItems: 3, hasWidget: true, familySize: 3)),
            .dailyUsage(dayIndex: 5, AnalyticsEvent.UsageDay(used: [.reminderAction])),
            .dailyUsage(dayIndex: 6, AnalyticsEvent.UsageDay(pro: .init(plan: nil, liveActivity: false, customIcon: true, customSound: false))),
            .dailyUsage(dayIndex: 7, AnalyticsEvent.UsageDay(pro: .init(plan: .yearly, liveActivity: true, customIcon: false, customSound: true))),
            .coreError(.schedule, .tooMany),
            .notificationPermission(.quiet, previous: nil),
            .showNamesChanged(false),
            .appColorChanged(.mint),
            .allAlarmChanged(true),
            .allRemindAgainChanged(.untilRecorded),
            .allRemindAgainChanged(nil),
            .allRemindAgainIntervalChanged(.minutes60),
            .headerWashChanged(false),
            .appearanceChanged(.dark),
            .onboardingResult(.yielded),
            .dataAction(.restore, .newerFile),
            .feedbackOpened,
            .paywallShown(.day7Card),
            .paywallShown(.family),
            .paywallShown(.liveActivity),
            .purchaseResult(.purchased, plan: .lifetime),
            .purchaseResult(.restored, plan: nil),
            .purchaseResult(.dismissed, plan: nil),
        ]
        for event in built {
            #expect(try AnalyticsEvent(name: event.name, properties: event.properties) == event)
        }
    }

    @Test func consentFollowsTheRegion() throws {
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

        // Elsewhere: on from the start, with no notice (D078).
        let preference = AnalyticsPreference(defaults: defaults, regionCode: "US")
        #expect(preference.isOn && preference.isActive && !preference.needsNotice)
        preference.set(false)
        #expect(!preference.isActive && !preference.isOn)

        let optIn = AnalyticsPreference(defaults: defaults, regionCode: "FR")
        optIn.set(true)
        #expect(optIn.isActive)
    }
}
