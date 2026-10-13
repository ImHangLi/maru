import Foundation
import MaruAnalytics
import MaruCore
import MaruDatabase

extension AppModel {
    /// The analytics of the app (spec 11, D051, D052). The project key and host come from the build settings
    /// `MARU_ANALYTICS_KEY` and `MARU_ANALYTICS_HOST` through the Info.plist. With an empty key, analytics is not available:
    /// the app has no switch, no notice, and only the null client.
    static func makeAnalytics() -> AnalyticsService {
        let info = Bundle.main.infoDictionary
        let configuration = PostHogConfiguration(
            apiKey: info?["MaruAnalyticsKey"] as? String ?? "",
            host: info?["MaruAnalyticsHost"] as? String ?? ""
        )
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        // One read for the consent rule and for the region field of the events, so the two always agree (D064).
        let regionCode = Locale.current.region?.identifier
        return AnalyticsService(
            isAvailable: configuration != nil,
            preference: AnalyticsPreference(regionCode: regionCode)
        ) {
            guard let configuration else { return NullAnalyticsClient() }
            return PostHogClient(
                configuration: configuration,
                appVersion: version,
                osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                regionCode: regionCode
            )
        }
    }

    /// A build with no key has no switch and no notice.
    var analyticsIsAvailable: Bool { analytics.isAvailable }

    /// The value of the switch in settings.
    var sharesUsageStatistics: Bool { analytics.isOn }

    func setSharesUsageStatistics(_ isOn: Bool) {
        analytics.setOn(isOn)
        analyticsNotice = false
    }

    /// The first save of an item is a quiet moment for the one-time notice (spec 11.3).
    func offerAnalyticsNotice() {
        if analytics.needsNotice { analyticsNotice = true }
    }

    /// The user saw the notice. In a region with the default "on", analytics starts now.
    func analyticsNoticeDidShow() {
        analyticsNotice = false
        analytics.noticeDidShow()
    }

    /// A storage error as one code of the `core_error` event. The code never carries a message or a path.
    func reportCoreError(_ operation: AnalyticsEvent.Operation, _ error: StorageError) {
        let code: AnalyticsEvent.ErrorCode = switch error {
        case .unavailable: .locked
        case .corrupt: .corrupt
        case .newerSchema: .newerSchema
        case .migrationFailed: .migrationFailed
        default: .failed
        }
        analytics.capture(.coreError(operation, code))
    }
}
