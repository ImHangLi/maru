import Foundation
import MaruCore
import MaruDatabase
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
    /// What the items that have a time share for "Alarm" and "Remind Again" (D085). `nil` before the first read.
    var reminderOptions: ReminderOptionsSummary?
    /// What a new item starts with. It holds the last choice of the user in Settings (D085).
    var newItemReminders = NewItemReminders.load()
    /// The system refused alarms at the tap on the "Alarm" switch (D085).
    var alarmsAreOff = false
}

extension AppModel {
    func openSettings() {
        settings.isPresented = true
        analytics.markUsed(.settings)
        readNotificationPermission()
        loadReminderOptions()
    }

    /// Reads what the items that have a time share, for the rows "Alarm" and "Remind Again" (D085).
    func loadReminderOptions() {
        let generation = dataGeneration
        Task {
            guard let items = try? await store.timedItems(), generation == dataGeneration else { return }
            settings.reminderOptions = ReminderOptionsSummary(items: items)
        }
    }

    /// "Remind Again" for every item that has a time (D085). Each item gets the count and one interval: the one that
    /// the items with "Remind Again" on share, else the one that the user chose last. Off turns it off everywhere.
    func setAllFollowUpCount(_ count: FollowUpCount?) {
        var style = settings.newItemReminders
        if case let .same(shared)? = settings.reminderOptions?.followUpInterval { style.interval = shared }
        style.followUp = count
        keep(style)
        analytics.capture(.allRemindAgainChanged(count))
        applyToTimedItems(.followUp(style.followUpSetting))
    }

    /// A new interval for every item that has "Remind Again" on (D085).
    func setAllFollowUpInterval(_ interval: FollowUpInterval) {
        var style = settings.newItemReminders
        style.interval = interval
        keep(style)
        analytics.capture(.allRemindAgainIntervalChanged(interval))
        applyToTimedItems(.followUpInterval(interval))
    }

    /// "Alarm" for every item that has a time (D085). The first turn-on asks the system for the permission. A refusal
    /// changes nothing and shows the alert.
    func setAllAlarms(_ isOn: Bool) {
        Task {
            if isOn, !(await allowAlarms()) {
                settings.alarmsAreOff = true
                return
            }
            var style = settings.newItemReminders
            style.alarm = isOn
            keep(style)
            analytics.capture(.allAlarmChanged(isOn))
            applyToTimedItems(.alarm(isOn))
        }
    }

    private func keep(_ style: NewItemReminders) {
        settings.newItemReminders = style
        style.save()
    }

    /// One transaction for every item that has a time, then one run of the reminder engines. A run that cannot start
    /// changes nothing, and the next launch or return runs again (D085).
    private func applyToTimedItems(_ change: ReminderOptionChange) {
        let now = Date()
        let generation = dataGeneration
        Task {
            do throws(StorageError) {
                let changed = try await store.apply(change, at: now, generation: generation)
                loadReminderOptions()
                guard changed > 0 else { return }
                refresh()
            } catch .replaced {
                // A restore replaced the data that Settings read.
                return refresh()
            } catch {
                reportCoreError(.save, error)
                return loadReminderOptions()
            }
            guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
            await runReminders(at: now, deviceTimeZone: deviceTimeZone)
        }
    }

    /// Reads the permission. It never asks for it again, so the system prompt does not show (spec 2.2, T13).
    func readNotificationPermission() {
        Task {
            let permission = await NotificationPermission.current()
            settings.permission = permission
            notePermission(permission)
        }
    }

    /// The user chose an app color in Settings. A restore of a backup sends nothing.
    func appColorDidChange(_ color: ItemColor) {
        analytics.capture(.appColorChanged(color))
    }

    /// "Show Names in Reminders". It starts on (D029).
    var showsNamesInReminders: Bool {
        DefaultsReminderPrivacy().load() == .showNames
    }

    /// Saves the setting, then replaces the reminders, the follow-ups, and the alarms with the new text (D029).
    /// A repeating request keeps the text that it got when it was added, so the run adds each one again.
    ///
    /// With names, a time whose items have different weekdays needs one request for each weekday, so a plan
    /// can lose its reminder to the request budget. The run reports as a save does: the state in the item
    /// detail, and one alert for each kind of new failure. A failed run changes nothing, and the next launch
    /// or return runs again.
    func setShowsNamesInReminders(_ showsNames: Bool) {
        DefaultsReminderPrivacy().save(showsNames ? .showNames : .hideNames)
        analytics.capture(.showNamesChanged(showsNames))
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
        Task { await runReminders(at: now, deviceTimeZone: deviceTimeZone) }
    }

    /// One run of the reminder engines for a change that touches many items. It reports like a save does.
    private func runReminders(at now: Date, deviceTimeZone: NamedTimeZone) async {
        let before = reminderStatus
        reminderRunDidEnd(try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone))
        var told = Set<ReminderStatus>()
        for (id, status) in reminderStatus where status != before[id] && told.insert(status).inserted {
            report(status, of: id, removes: false)
        }
    }
}
