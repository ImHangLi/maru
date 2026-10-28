import MaruCore
import MaruNotifications
import SwiftUI
import UIKit

/// The settings sheet behind the gear button (spec 3 P06, D020, D021). Few rows, plain words.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @AppStorage(DisplaySetting.headerWash) private var headerWash = false
    @State private var showsNames = true
    @State private var sharesStatistics = false

    var body: some View {
        NavigationStack {
            Form {
                ReminderSection(showsNames: Binding(
                    get: { showsNames },
                    set: {
                        showsNames = $0
                        model.setShowsNamesInReminders($0)
                    }
                ))
                AllItemsSection()
                Section("Display") {
                    // A system menu of the eight colors (D025, D026).
                    Picker("App Color", selection: Binding(
                        get: { appColor },
                        set: {
                            appColor = $0
                            model.appColorDidChange($0)
                        }
                    )) {
                        ForEach(ItemColor.allCases, id: \.self) { color in
                            Label { Text(color.title) } icon: { color.tint.circleImage }
                                .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                    // The wash of the app color behind the title, as in Apple Health (D100).
                    Toggle("Color Header", isOn: $headerWash)
                    // iOS sets the app language on the Settings page of Maru (D097).
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        LabeledContent("Language") {
                            Text(verbatim: Self.languageName)
                        }
                    }
                    .rowText()
                }
                if model.analyticsIsAvailable {
                    Section {
                        Toggle("Share Usage Statistics", isOn: Binding(
                            get: { sharesStatistics },
                            set: {
                                sharesStatistics = $0
                                model.setSharesUsageStatistics($0)
                            }
                        ))
                    } footer: {
                        Text("Never includes item names, doses, or times.")
                    }
                }
                DataSection()
                FeedbackSection()
                AboutSection()
                #if DEBUG
                DebugSection()
                #endif
            }
            // The rows and the footer of "Reminders" come and go with the permission (D030).
            .motion(.layout, value: model.settings.permission)
            .motion(.layout, value: model.settings.reminderOptions)
            #if DEBUG
            .modifier(DebugDataBanner())
            #endif
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // A restore replaces the data while it runs. The sheet stays until it ends (D040).
                if !model.transfer.isRestoring {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(model.transfer.isRestoring)
        // The sheet sets the tint again, so every control in it changes at once with a new app color.
        .tint(appColor.tint)
        .onAppear {
            showsNames = model.showsNamesInReminders
            sharesStatistics = model.sharesUsageStatistics
        }
        // A return from the Settings app shows the new permission (T14).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.readNotificationPermission() }
        }
    }

    /// The name of the language that the app uses, in that language, for example "English" or "日本語".
    private static var languageName: String {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: identifier)
        return locale.localizedString(forIdentifier: identifier)?.capitalized(with: locale) ?? identifier
    }
}

/// The honest reminder state and the way to fix it (spec 2.2, T13, T14). The switch for the names is here too, because
/// it is about what a reminder shows.
private struct ReminderSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Binding var showsNames: Bool

    var body: some View {
        let permission = model.settings.permission
        Section {
            LabeledContent("Notifications") {
                Text(statusText(permission))
            }
            if permission == .denied || permission == .quiet {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .rowText()
            }
            Toggle("Show Names in Reminders", isOn: $showsNames)
        } header: {
            Text("Reminders")
        } footer: {
            if let text = footerText(permission) { Text(text) }
        }
    }

    private func statusText(_ permission: NotificationPermission?) -> LocalizedStringKey {
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
