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
    @AppStorage(DisplaySetting.headerWash) private var headerWash = true
    @AppStorage(DisplaySetting.appearance) private var appearance = AppAppearance.system
    @State private var showsNames = true
    @State private var sharesStatistics = false
    /// A color that a free user chose and did not buy. It tints only this sheet, until the sheet closes (D114).
    @State private var previewColor: ItemColor?

    var body: some View {
        NavigationStack {
            Form {
                // At the top, so a user who looks for it finds it (D107).
                ProSection()
                // Under Maru Pro, as the Family row of iOS Settings (D121).
                FamilySection()
                ReminderSection(showsNames: Binding(
                    get: { showsNames },
                    set: {
                        showsNames = $0
                        model.setShowsNamesInReminders($0)
                    }
                ))
                NextDoseSection()
                AllItemsSection()
                Section {
                    // A system menu of the eight colors (D025, D026). Only pink is free (D114).
                    Picker("App Color", selection: Binding(
                        get: { previewColor ?? appColor },
                        set: { chooseAppColor($0) }
                    )) {
                        ForEach(ItemColor.allCases, id: \.self) { color in
                            Label { Text(color.title) } icon: { color.tint.circleImage }
                                .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                    // The icons of Maru Pro, with a free look at each one (D112).
                    if UIApplication.shared.supportsAlternateIcons {
                        NavigationLink {
                            AppIconView()
                        } label: {
                            LabeledContent("App Icon") {
                                AppIconPreview(icon: model.settings.appIcon, size: 29)
                                    .accessibilityLabel(Text(model.settings.appIcon.title))
                            }
                        }
                    }
                    // The wash of the app color behind the title, as in Apple Health (D100).
                    // A binding of its own sends the change of the user only, not the change of a restore (D127).
                    Toggle("Color Header", isOn: Binding(get: { headerWash }, set: {
                        headerWash = $0
                        model.headerWashDidChange($0)
                    }))
                    // The system look, or always light or dark (D105).
                    Picker("Appearance", selection: Binding(get: { appearance }, set: {
                        appearance = $0
                        model.appearanceDidChange($0)
                    })) {
                        ForEach(AppAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                    // iOS sets the app language on the Settings page of Maru (D097).
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        LabeledContent("Language") {
                            Text(verbatim: Self.languageName)
                        }
                    }
                    .rowText()
                } header: {
                    Text("Display")
                } footer: {
                    if previewColor != nil {
                        Text("This is a preview. With Maru Pro, the whole app uses this color.")
                    }
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
        // A paywall from a row of Settings shows over this sheet (D107).
        .paywallHost(true)
        .interactiveDismissDisabled(model.transfer.isRestoring)
        // The sheet sets the tint again, so every control in it changes at once with a new app color. A preview of a
        // free user tints only this sheet (D114).
        .tint((previewColor ?? appColor).tint)
        // A purchase while a preview shows keeps the color of the preview.
        .onChange(of: model.pro.isPro) { _, isPro in
            if isPro, let previewColor { chooseAppColor(previewColor) }
        }
        .onAppear {
            showsNames = model.showsNamesInReminders
            sharesStatistics = model.sharesUsageStatistics
        }
        // A return from the Settings app shows the new permission (T14).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.readNotificationPermission() }
        }
    }

    /// Pink is free. Another color needs Pro, also after Pro ends, so a free user sees a preview and the paywall (D114).
    private func chooseAppColor(_ color: ItemColor) {
        guard color == .pink || color == appColor || model.pro.isPro else {
            previewColor = color
            return model.presentPaywall(reason: .appColor)
        }
        previewColor = nil
        guard color != appColor else { return }
        appColor = color
        model.appColorDidChange(color)
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
            // The sounds of Maru Pro, with a free preview of each one (D112).
            NavigationLink {
                ReminderSoundView()
            } label: {
                LabeledContent("Reminder Sound") {
                    if let sound = model.reminderSound { Text(sound.title) } else { Text("Default") }
                }
            }
        } header: {
            Text("Reminders")
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

/// "Next Dose on Lock Screen", a Live Activity of Maru Pro (D110). For a free user, the switch opens the paywall and
/// stays off. The iPad has no Live Activities, so it has no row.
private struct NextDoseSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            Section {
                Toggle("Next Dose on Lock Screen", isOn: Binding(
                    get: { model.liveActivity.isOn },
                    set: { model.setNextDoseOnLockScreen($0) }
                ))
            } footer: {
                if model.liveActivity.systemAllows {
                    Text("Shows your next dose, its time, and a button to record it.")
                } else {
                    Text("Live Activities are off for Maru. Turn them on in the Settings app, under Maru.")
                }
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
