import MaruCore
import MaruNotifications
import SwiftUI
import UIKit

/// The settings sheet behind the gear button (spec 3 P06, D020, D021). Few rows, plain words.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    /// `nil` means off.
    @State private var followUpCount: FollowUpCount?
    /// 30 minutes until the user picks one: the middle delay of D021, and the delay of Apple Health.
    @State private var followUpInterval = FollowUpInterval.minutes30
    @State private var showsNames = true
    @State private var sharesStatistics = false

    var body: some View {
        NavigationStack {
            Form {
                ReminderSection()
                Section {
                    Toggle("Show Names in Reminders", isOn: Binding(
                        get: { showsNames },
                        set: {
                            showsNames = $0
                            model.setShowsNamesInReminders($0)
                        }
                    ))
                } footer: {
                    Text("Turn off to keep item names out of reminders.")
                }
                Section {
                    Picker("Remind Again", selection: Binding(
                        get: { followUpCount },
                        set: { count in
                            // The interval row comes and goes with "Off" (D039).
                            withMotion(.layout) { followUpCount = count }
                            model.setFollowUp(count.map { FollowUpSetting(count: $0, interval: followUpInterval) })
                        }
                    )) {
                        Text("Off").tag(FollowUpCount?.none)
                        Text("1 Time").tag(FollowUpCount?.some(.one))
                        Text("2 Times").tag(FollowUpCount?.some(.two))
                        Text("3 Times").tag(FollowUpCount?.some(.three))
                        Text("5 Times").tag(FollowUpCount?.some(.five))
                        Text("Until Recorded").tag(FollowUpCount?.some(.untilRecorded))
                    }
                    // The menu button keeps the tint that it had before. A new identity redraws it in the new app color.
                    .id(appColor)
                    if followUpCount != nil {
                        Picker("Every", selection: Binding(
                            get: { followUpInterval },
                            set: { interval in
                                followUpInterval = interval
                                model.setFollowUp(followUpCount.map { FollowUpSetting(count: $0, interval: interval) })
                            }
                        )) {
                            Text("5 min").tag(FollowUpInterval.minutes5)
                            Text("10 min").tag(FollowUpInterval.minutes10)
                            Text("15 min").tag(FollowUpInterval.minutes15)
                            Text("30 min").tag(FollowUpInterval.minutes30)
                            Text("1 hr").tag(FollowUpInterval.minutes60)
                        }
                        .id([appColor.rawValue, "interval"])
                    }
                } footer: {
                    // iPhone has no reminder that repeats until Maru stops it, so "Until Recorded" has a limit.
                    // The footer states it, and the time at which the follow-ups of a dose stop (D039).
                    if followUpCount == .untilRecorded {
                        let latest = FollowUpPlan.latestTime
                        let time = SchedulePreview.format(hour: latest.hour, minute: latest.minute)
                        Text("Maru reminds you up to \(FollowUpCount.untilRecordedLimit) times for each dose, until \(time) at the latest.")
                    } else {
                        Text("Only for doses with no record.")
                    }
                }
                Section("Display") {
                    // A system menu of the eight colors (D025, D026).
                    Picker("App Color", selection: $appColor) {
                        ForEach(ItemColor.allCases, id: \.self) { color in
                            Label { Text(color.title) } icon: { color.tint.circleImage }
                                .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
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
                        Text("Maru shares how you use the app, and never item names, doses, or times.")
                    }
                }
                DataSection()
                FeedbackSection()
                SupportSection()
                AboutSection()
                #if DEBUG
                DebugSection()
                #endif
            }
            // The rows and the footer of "Reminders" come and go with the permission and the test (D030).
            .motion(.layout, value: model.settings.permission)
            .motion(.layout, value: model.settings.test)
            #if DEBUG
            .modifier(DebugDataBanner())
            #endif
            .navigationTitle("Settings")
            // The tip section shows only after its products load, so the load starts here.
            .task { await SupportStore.shared.loadProducts() }
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
            let followUp = model.followUpSetting
            followUpCount = followUp?.count
            if let followUp { followUpInterval = followUp.interval }
            showsNames = model.showsNamesInReminders
            sharesStatistics = model.sharesUsageStatistics
        }
        // A return from the Settings app shows the new permission (T14).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.readNotificationPermission() }
        }
    }
}

/// The honest reminder state, the way to fix it, and the test (spec 2.2, T13, T14).
private struct ReminderSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

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
            }
            // The test shows only when it can arrive. A disabled row would add words and no action.
            if canTest(permission) {
                Button("Send a Test Notification") { model.sendTestNotification() }
                    .disabled(model.settings.test == .sending)
            }
        } header: {
            Text("Reminders")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let text = footerText(permission) { Text(text) }
                if let text = testText { Text(text) }
            }
        }
    }

    private func canTest(_ permission: NotificationPermission?) -> Bool {
        permission == .allowed || permission == .quiet
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

    private var testText: LocalizedStringKey? {
        switch model.settings.test {
        case .idle, .sending: nil
        case .sent: "The test comes in about 5 seconds."
        case .notAllowed: "Maru did not send the test, because notifications are off."
        case .noRoom: "Maru did not send the test, because your iPhone can’t hold more reminders."
        case .failed: "Maru did not send the test, so try again."
        }
    }
}
