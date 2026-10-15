import MaruCore
import SwiftUI

/// The words of "Remind Again", shared by Settings and the add and edit screen so both say the same (D058, D085).
extension FollowUpCount {
    var title: LocalizedStringKey {
        switch self {
        case .one: "1 Time"
        case .two: "2 Times"
        case .three: "3 Times"
        case .five: "5 Times"
        case .untilRecorded: "Until I Record It"
        }
    }
}

extension FollowUpInterval {
    var title: LocalizedStringKey {
        switch self {
        case .minutes5: "5 min"
        case .minutes10: "10 min"
        case .minutes15: "15 min"
        case .minutes30: "30 min"
        case .minutes60: "1 hr"
        }
    }
}

/// The one short line about the limit of "Until I Record It": iPhone has no reminder that repeats with no end, so
/// Maru states the number and the last time (D039).
struct UntilRecordedLimitText: View {
    var body: some View {
        let latest = FollowUpPlan.latestTime
        let time = SchedulePreview.format(hour: latest.hour, minute: latest.minute)
        Text("Reminds you up to \(FollowUpCount.untilRecordedLimit) times, until \(time).")
    }
}

/// What a new item starts with for the two reminder options: the value that the user last chose in Settings (D085).
/// It is a reminder style and not a dose or a time, so a start value does not break spec 2.1. The preference is not
/// health data, so it lives in `UserDefaults.standard` with the other settings (D014).
struct NewItemReminders: Equatable {
    /// `nil` is off.
    var followUp: FollowUpCount?
    /// The interval that "Remind Again" gets when the user turns it on. 30 minutes until the user picks one (D039).
    var interval = FollowUpInterval.minutes30
    var alarm = false

    private enum Key {
        static let count = "reminders.newItem.followUpCount"
        static let minutes = "reminders.newItem.followUpMinutes"
        static let alarm = "reminders.newItem.alarm"
    }

    var followUpSetting: FollowUpSetting? {
        followUp.map { FollowUpSetting(count: $0, interval: interval) }
    }

    static func load(_ defaults: UserDefaults = .standard) -> NewItemReminders {
        var value = NewItemReminders()
        value.followUp = (defaults.object(forKey: Key.count) as? Int).flatMap(FollowUpCount.init(rawValue:))
        value.interval = (defaults.object(forKey: Key.minutes) as? Int).flatMap(FollowUpInterval.init(rawValue:)) ?? .minutes30
        value.alarm = defaults.bool(forKey: Key.alarm)
        return value
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let followUp { defaults.set(followUp.rawValue, forKey: Key.count) } else { defaults.removeObject(forKey: Key.count) }
        defaults.set(interval.rawValue, forKey: Key.minutes)
        defaults.set(alarm, forKey: Key.alarm)
    }
}
