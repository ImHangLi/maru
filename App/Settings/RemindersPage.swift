import MaruCore
import MaruNotifications
import SwiftUI
import UIKit

/// The page "Reminders": the reminder state, the text and the sound of a reminder, and the options for all items (D135).
struct RemindersPage: View {
    @Environment(AppModel.self) private var model
    @State private var showsNames = true

    var body: some View {
        Form {
            ReminderSection(showsNames: Binding(
                get: { showsNames },
                set: {
                    showsNames = $0
                    model.setShowsNamesInReminders($0)
                }
            ))
            AllItemsSection()
        }
        // The rows and the footer of the reminder state come and go with the permission (D030).
        .motion(.layout, value: model.settings.permission)
        .motion(.layout, value: model.settings.reminderOptions)
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { showsNames = model.showsNamesInReminders }
    }
}

/// The page "Lock Screen" with "Next Dose on Lock Screen" (D110, D135). Only the iPhone has it.
struct LockScreenPage: View {
    var body: some View {
        Form {
            NextDoseSection()
        }
        .navigationTitle("Lock Screen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The honest reminder state and the way to fix it (spec 2.2, T13, T14). The switch for the names is here too, because
/// it is about what a reminder shows.
struct ReminderSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Binding var showsNames: Bool

    var body: some View {
        let permission = model.settings.permission
        Section {
            LabeledContent("Notifications") {
                Text(Self.statusText(permission))
            }
            if permission == .denied || permission == .quiet {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .rowText()
            }
            Toggle("Show Names in Reminders", isOn: $showsNames)
            // The sounds of Maru Pro, with a free preview of each one (D112).
            NavigationLink(value: SettingsPage.reminderSound) {
                LabeledContent {
                    if let sound = model.reminderSound { Text(sound.title) } else { Text("Default") }
                } label: {
                    ProRowTitle("Reminder Sound")
                }
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let text = footerText(permission) { Text(text) }
                // Only with a second active member, so a user of one member sees no change (T57, D129).
                if model.hasFamily {
                    Text("With names on, reminders also name the person or pet.")
                }
            }
        }
    }

    /// The state of the notification permission. The root row of Settings shows it too.
    static func statusText(_ permission: NotificationPermission?) -> LocalizedStringKey {
        switch permission {
        case nil: "Checking…"
        case .allowed: "On"
        case .quiet: "Quiet"
        case .denied: "Off"
        case .notAsked: "Not Asked Yet"
        }
    }

    private func footerText(_ permission: NotificationPermission?) -> LocalizedStringKey? {
        switch permission {
        case nil, .allowed: nil
        case .quiet: "Reminders come with no sound or banner."
        case .denied: "You can still record without reminders."
        case .notAsked: "Maru asks when you save an item with a time."
        }
    }
}

/// "Next Dose on Lock Screen", a Live Activity of Maru Pro (D110). For a free user, the switch opens the paywall and
/// stays off.
private struct NextDoseSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { model.liveActivity.isOn },
                set: { model.setNextDoseOnLockScreen($0) }
            )) {
                ProRowTitle("Next Dose on Lock Screen")
            }
        } footer: {
            if model.liveActivity.systemAllows {
                Text("Shows your next dose, its time, and a button to record it.")
            } else {
                Text("Live Activities are off for Maru. Turn them on in the Settings app, under Maru.")
            }
        }
    }
}

/// "Alarm" and "Remind Again" for every item that has a time (D085). A row shows the value that every item has.
/// When the items differ, the row says "Varies", and a choice sets every item. An item can still have its own value on
/// its edit screen.
private struct AllItemsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    private enum CountChoice: Hashable {
        case varies
        case off
        case count(FollowUpCount)
    }

    private enum IntervalChoice: Hashable {
        case varies
        case interval(FollowUpInterval)
    }

    private enum AlarmChoice: Hashable {
        case varies, on, off
    }

    private var summary: ReminderOptionsSummary? { model.settings.reminderOptions }
    private var start: NewItemReminders { model.settings.newItemReminders }

    var body: some View {
        @Bindable var model = model
        Section {
            if #available(iOS 26, *) { alarmRow }
            Picker("Remind Again", selection: countChoice) {
                if countChoice.wrappedValue == .varies { Text("Varies").tag(CountChoice.varies) }
                Text("Off").tag(CountChoice.off)
                ForEach(FollowUpCount.allCases, id: \.self) { count in
                    Text(count.title).tag(CountChoice.count(count))
                }
            }
            .tint(Color.primary)
            if showsInterval {
                Picker("Every", selection: intervalChoice) {
                    if intervalChoice.wrappedValue == .varies { Text("Varies").tag(IntervalChoice.varies) }
                    ForEach(FollowUpInterval.allCases, id: \.self) { interval in
                        Text(interval.title).tag(IntervalChoice.interval(interval))
                    }
                }
                .tint(Color.primary)
            }
        } header: {
            Text("For All Items")
        } footer: {
            if countChoice.wrappedValue == .count(.untilRecorded) { UntilRecordedLimitText() }
        }
        .alert("Alarms Are Off", isPresented: $model.settings.alarmsAreOff) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To use an alarm, allow alarms for Maru in Settings.")
        }
    }

    /// A switch while every item has the same value. A menu with "Varies" while they differ.
    @available(iOS 26, *)
    @ViewBuilder private var alarmRow: some View {
        if summary?.alarm == .varies {
            Picker("Alarm", selection: alarmChoice) {
                Text("Varies").tag(AlarmChoice.varies)
                Text("On").tag(AlarmChoice.on)
                Text("Off").tag(AlarmChoice.off)
            }
            .tint(Color.primary)
        } else {
            Toggle("Alarm", isOn: Binding(
                get: { alarmIsOn },
                set: { model.setAllAlarms($0) }
            ))
        }
    }

    private var alarmIsOn: Bool {
        if case let .same(isOn)? = summary?.alarm { isOn } else { start.alarm }
    }

    private var alarmChoice: Binding<AlarmChoice> {
        Binding {
            summary?.alarm == .varies ? .varies : alarmIsOn ? .on : .off
        } set: { choice in
            if choice != .varies { model.setAllAlarms(choice == .on) }
        }
    }

    /// The interval row shows while at least one item has "Remind Again" on, or, with no item to show, while the
    /// start value of a new item has it on.
    private var showsInterval: Bool {
        switch summary?.followUpCount {
        case let .same(count)?: count != nil
        case .varies?: summary?.followUpInterval != SharedValue<FollowUpInterval>.empty
        case .empty?, nil: start.followUp != nil
        }
    }

    private var countChoice: Binding<CountChoice> {
        Binding {
            switch summary?.followUpCount {
            case let .same(count)?: count.map(CountChoice.count) ?? .off
            case .varies?: .varies
            case .empty?, nil: start.followUp.map(CountChoice.count) ?? .off
            }
        } set: { choice in
            switch choice {
            case .varies: break
            case .off: model.setAllFollowUpCount(nil)
            case let .count(count): model.setAllFollowUpCount(count)
            }
        }
    }

    private var intervalChoice: Binding<IntervalChoice> {
        Binding {
            switch summary?.followUpInterval {
            case let .same(interval)?: .interval(interval)
            case .varies?: .varies
            case .empty?, nil: .interval(start.interval)
            }
        } set: { choice in
            if case let .interval(interval) = choice { model.setAllFollowUpInterval(interval) }
        }
    }
}
