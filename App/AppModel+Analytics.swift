import Foundation
import MaruAnalytics
import MaruCore
import MaruDatabase
import MaruNotifications
import UIKit
import WidgetKit

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
        // The language that the app shows, not the language list of the device (D077).
        let language = Bundle.main.preferredLocalizations.first
        let device: PostHogClient.DeviceFamily = switch UIDevice.current.userInterfaceIdiom {
        case .phone: .iphone
        case .pad: .ipad
        default: .other
        }
        return AnalyticsService(
            isAvailable: configuration != nil,
            preference: AnalyticsPreference(regionCode: regionCode)
        ) {
            guard let configuration else { return NullAnalyticsClient() }
            return PostHogClient(
                configuration: configuration,
                appVersion: version,
                osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                regionCode: regionCode,
                language: language,
                device: device
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

    /// The first save of an item is a quiet moment for the one-time opt-in question (spec 11.3). Only an opt-in
    /// region asks. Elsewhere analytics is on with no notice (D078).
    func offerAnalyticsNotice() {
        if analytics.needsNotice { analyticsNotice = true }
    }

    /// The user saw the opt-in question. The answer, if any, goes through `setSharesUsageStatistics`.
    func analyticsNoticeDidShow() {
        analyticsNotice = false
        analytics.noticeDidShow()
    }

    /// A part of the app that the user used today (D077). One bit for the day, with no time and no count.
    func noteUse(_ flag: AnalyticsEvent.UsageFlag) {
        analytics.markUsed(flag)
    }

    /// The app came to the front. It counts the open of the day, and it checks for a widget off the main thread.
    /// Nothing waits for the check (spec 9).
    func noteOpen() {
        analytics.noteOpen()
        guard analytics.isActive else { return }
        // The system calls back on a queue of its own, so the closure has no actor.
        WidgetCenter.shared.getCurrentConfigurations { @Sendable result in
            guard let installed = (try? result.get()).map({ !$0.isEmpty }) else { return }
            Task { @MainActor in AppModel.shared.analytics.noteWidget(installed: installed) }
        }
    }

    /// The permission that the app read. The service sends an event only when it differs from the last one sent.
    func notePermission(_ permission: NotificationPermission) {
        let state: AnalyticsEvent.Permission = switch permission {
        case .notAsked: .notAsked
        case .allowed: .allowed
        case .denied: .denied
        case .quiet: .quiet
        }
        analytics.notePermission(state)
    }

    /// The record flags of the day from committed records (D077): a skip, an undo, a correction of an earlier
    /// record, and a record from the "Taken" action of a reminder. No time and no count leaves the device.
    func noteRecords(_ records: [OccurrenceRecord]) {
        analytics.markUsed(.record)
        for record in records {
            guard let last = record.events.last else { continue }
            switch last.action {
            case .skipped: analytics.markUsed(.skip)
            case .undo: analytics.markUsed(.undo)
            case .taken: break
            }
            if last.action != .undo, let earlier = record.events.first(where: { $0.id == last.supersedes }),
               earlier.action != .undo {
                analytics.markUsed(.correction)
            }
            if last.source == .notificationAction { analytics.markUsed(.reminderAction) }
        }
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
