import Foundation
import MaruCore
import MaruNotifications

/// The keys of the display settings in `UserDefaults.standard`. The views read them with `@AppStorage`.
///
/// Preferences are not in the health database, because that file cannot be read after a restart and before the first unlock
/// (D014). No app color means pink.
enum DisplaySetting {
    /// The app tint, as the raw value of an `ItemColor` (D025).
    static let appColor = "display.appColor"
}

/// The state of the settings sheet that is not in `UserDefaults`.
struct SettingsState {
    var isPresented = false
    /// The permission at the last read. `nil` before the first read, so no screen shows a guess.
    var permission: NotificationPermission?
}

extension AppModel {
    /// The follow-up setting. It starts off (spec 4).
    var followUpSetting: FollowUpSetting? {
        DefaultsFollowUpSetting().load()
    }

    func openSettings() {
        settings.isPresented = true
        readNotificationPermission()
    }

    /// Reads the permission. It never asks for it again, so the system prompt does not show (spec 2.2, T13).
    func readNotificationPermission() {
        Task {
            settings.permission = await NotificationPermission.current()
        }
    }

    /// Saves the setting, then sets the follow-ups again in the notification queue (spec 4, D021, D039).
    func setFollowUp(_ setting: FollowUpSetting?) {
        DefaultsFollowUpSetting().save(setting)
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        Task { [store] in
            await store.refreshFollowUps(at: now, deviceTimeZone: deviceTimeZone)
        }
    }

    /// "Show Names in Reminders". It starts on (D029).
    var showsNamesInReminders: Bool {
        DefaultsReminderPrivacy().load() == .showNames
    }

    /// Saves the setting, then replaces the reminders and the follow-ups with the new text (D029).
    /// A repeating request keeps the text that it got when it was added, so the run adds each one again.
    ///
    /// With names, a time whose items have different weekdays needs one request for each weekday, so a plan
    /// can lose its reminder to the request budget. The run reports as a save does: the state in the item
    /// detail, and one alert for each kind of new failure. A failed run changes nothing, and the next launch
    /// or return runs again.
    func setShowsNamesInReminders(_ showsNames: Bool) {
        DefaultsReminderPrivacy().save(showsNames ? .showNames : .hideNames)
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        Task {
            let before = reminderStatus
            reminderRunDidEnd(try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone))
            var told = Set<ReminderStatus>()
            for (id, status) in reminderStatus where status != before[id] && told.insert(status).inserted {
                report(status, of: id, removes: false)
            }
        }
    }
}
