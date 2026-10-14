import AlarmKit
import AppIntents
import Foundation
import MaruCore
import MaruNotifications
import SwiftUI

/// What AlarmKit needs from Maru for the alarm: nothing. The alarm shows the title and the two buttons that
/// `SystemAlarmCenter` gives it.
@available(iOS 26, *)
struct MaruAlarmMetadata: AlarmMetadata {}

/// The state of the alarm permission (D079). AlarmKit exists from iOS 26. Before that, no item can have an alarm.
enum AlarmSupport {
    /// The user can turn an alarm on: iOS 26 or later.
    static var isAvailable: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    /// Alarms can ring now: iOS 26 or later, and the user allowed them. The engines read this at each run,
    /// so an item with an alarm gets its normal reminder when the user turns the permission off (D079).
    static var isAuthorized: Bool {
        if #available(iOS 26, *) { AlarmManager.shared.authorizationState == .authorized } else { false }
    }

    /// Asks the system at the first call. It returns `true` when alarms can ring. After a refusal, the system
    /// asks no more, so the call returns `false` and the user must use Settings.
    static func requestAuthorization() async -> Bool {
        guard #available(iOS 26, *) else { return false }
        if AlarmManager.shared.authorizationState == .authorized { return true }
        return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
    }
}

/// AlarmKit as an `AlarmCenter`. It only translates: `AlarmPlan` and `AlarmEngine` in `MaruCore` have every rule.
@available(iOS 26, *)
struct SystemAlarmCenter: AlarmCenter {
    func waiting() async -> Set<UUID> {
        guard let alarms = try? AlarmManager.shared.alarms else { return [] }
        return Set(alarms.filter { $0.state == .scheduled }.map(\.id))
    }

    func schedule(_ request: AlarmRequest) async throws {
        let text = SystemReminderCenter().text(for: ReminderContent(kind: .due, names: request.names))
        let title = request.names == nil ? text.title : "\(text.title) · \(text.body)"
        let secondary: AlarmButton
        let intent: any LiveActivityIntent
        if let taken = request.taken {
            // One item, alone at its time: the button records the dose with the checks of the "Taken" action (D034).
            secondary = AlarmButton(text: "Taken", textColor: .white, systemImageName: "checkmark")
            intent = TakeFromAlarmIntent(userInfo: taken)
        } else {
            secondary = AlarmButton(text: "Open Maru", textColor: .white, systemImageName: "arrow.up.forward.app")
            intent = OpenFromAlarmIntent()
        }
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
            secondaryButton: secondary,
            secondaryButtonBehavior: .custom
        )
        let color = UserDefaults.standard.string(forKey: DisplaySetting.appColor).flatMap(ItemColor.init(rawValue:)) ?? .pink
        let attributes = AlarmAttributes<MaruAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert), tintColor: color.tint
        )
        _ = try await AlarmManager.shared.schedule(
            id: request.id,
            configuration: .alarm(
                schedule: .fixed(request.fireDate),
                attributes: attributes,
                stopIntent: nil,
                secondaryIntent: intent,
                sound: .default
            )
        )
    }

    func cancel(_ ids: [UUID]) async {
        for id in ids { try? AlarmManager.shared.cancel(id: id) }
    }
}

/// The "Taken" button of an alarm for one item. It runs in the app process, in the background (D034, D079).
///
/// It holds the keys of a follow-up reminder: the series, the plan date, the item, and the schedule version.
/// It holds no name and no dose. `AppModel.takeReminder` records through the same checks as the "Taken" action
/// of a notification, so an alarm of an older plan, a dose of another day, or a dose with a record changes nothing.
struct TakeFromAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Record a Dose"
    /// Only an alarm runs it, so Shortcuts does not offer it.
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Dose")
    var seriesID: String
    @Parameter(title: "Dose")
    var plannedDate: String
    @Parameter(title: "Dose")
    var fireTime: String
    @Parameter(title: "Dose")
    var itemID: String
    @Parameter(title: "Dose")
    var scheduleVersionID: String

    init() {}

    init(userInfo: [String: String]) {
        seriesID = userInfo[ReminderRequest.seriesIDKey] ?? ""
        plannedDate = userInfo[FollowUpRequest.plannedDateKey] ?? ""
        fireTime = userInfo[FollowUpRequest.fireTimeKey] ?? ""
        itemID = userInfo[FollowUpRequest.itemIDKey] ?? ""
        scheduleVersionID = userInfo[FollowUpRequest.scheduleVersionIDKey] ?? ""
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let userInfo = [
            ReminderRequest.seriesIDKey: seriesID,
            FollowUpRequest.plannedDateKey: plannedDate,
            FollowUpRequest.fireTimeKey: fireTime,
            FollowUpRequest.itemIDKey: itemID,
            FollowUpRequest.scheduleVersionIDKey: scheduleVersionID,
        ]
        let firedAt = (try? Date(fireTime, strategy: .iso8601)) ?? Date()
        await AppModel.shared.takeReminder(DeliveredReminder(deliveredAt: firedAt, userInfo: userInfo, triggerWeekday: nil))
        return .result()
    }
}

/// The second button of an alarm for more than one item: it opens Maru, where the user records each dose (D079).
struct OpenFromAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open Maru"
    static var isDiscoverable: Bool { false }
    static var openAppWhenRun: Bool { true }

    init() {}

    func perform() async throws -> some IntentResult {
        .result()
    }
}
