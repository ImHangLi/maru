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
    func waiting() async throws -> Set<UUID> {
        // An error is an error of the alarm path: the run then has an empty cover, and every item gets its notification (D079).
        let alarms = try AlarmManager.shared.alarms
        return Set(alarms.filter { $0.state == .scheduled }.map(\.id))
    }

    func snapshot() async throws -> AlarmSnapshot {
        let alarms = try AlarmManager.shared.alarms
        return AlarmSnapshot(
            waiting: Set(alarms.filter { $0.state == .scheduled }.map(\.id)),
            active: Set(alarms.filter { $0.state == .alerting }.map(\.id))
        )
    }

    func active() async throws -> Set<UUID> {
        let alarms = try AlarmManager.shared.alarms
        return Set(alarms.filter { $0.state == .alerting }.map(\.id))
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
        // An alarm that repeats on weekdays uses the clock of the device and never runs out (D089).
        let schedule: Alarm.Schedule
        if let repeating = request.repeating {
            let time = Alarm.Schedule.Relative.Time(hour: repeating.time.hour, minute: repeating.time.minute)
            schedule = .relative(.init(time: time, repeats: .weekly(repeating.weekdays.sorted().map(Self.weekday))))
        } else {
            schedule = .fixed(request.fireDate)
        }
        _ = try await AlarmManager.shared.schedule(
            id: request.id,
            configuration: .alarm(
                schedule: schedule,
                attributes: attributes,
                stopIntent: RunAfterAlarmIntent(),
                secondaryIntent: intent,
                sound: .default
            )
        )
    }

    private static func weekday(_ day: Weekday) -> Locale.Weekday {
        switch day {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }

    func cancel(_ ids: [UUID]) async throws {
        var failure: (any Error)?
        for id in ids {
            do { try AlarmManager.shared.cancel(id: id) } catch { failure = error }
        }
        if let failure { throw failure }
    }
}

/// The "Taken" button of an alarm for one item. It runs in the app process, in the background (D034, D079).
///
/// It holds the keys of a follow-up reminder: the series, the plan date, the item, and the schedule version.
/// A repeating alarm has no plan date and no fire time, and the button finds the date when it runs.
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
        // A repeating alarm holds no date. The dose is today's, when its time has come (D089).
        let resolvedDate = plannedDate.isEmpty
            ? NamedTimeZone(device: .current, at: .now).flatMap {
                AlarmRequest.plannedDate(ofSeries: seriesID, at: .now, deviceTimeZone: $0)
            } ?? ""
            : plannedDate
        let userInfo = [
            ReminderRequest.seriesIDKey: seriesID,
            FollowUpRequest.plannedDateKey: resolvedDate,
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

/// The "Stop" button of an alarm. The app runs the reminders a moment later, so a repeating alarm that an edit made obsolete
/// is cancelled soon after it stops ringing (D089).
struct RunAfterAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Update Reminders"
    static var isDiscoverable: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try? await Task.sleep(for: .seconds(1))
        if let deviceTimeZone = NamedTimeZone(device: .current, at: .now) {
            await AppModel.shared.waitForReminders(deviceTimeZone: deviceTimeZone)
        }
        return .result()
    }
}
