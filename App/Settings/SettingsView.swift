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
    @State private var followUp: FollowUpDelay?
    @State private var showsNames = true

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
                        get: { followUp },
                        set: {
                            followUp = $0
                            model.setFollowUpDelay($0)
                        }
                    )) {
                        Text("Off").tag(FollowUpDelay?.none)
                        Text("After 15 min").tag(FollowUpDelay?.some(.minutes15))
                        Text("After 30 min").tag(FollowUpDelay?.some(.minutes30))
                        Text("After 1 hr").tag(FollowUpDelay?.some(.minutes60))
                    }
                    // The menu button keeps the tint that it had before. A new identity redraws it in the new app color.
                    .id(appColor)
                } footer: {
                    Text("Only for items that you did not record.")
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
                DataSection()
                FeedbackSection()
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
            .navigationBarTitleDisplayMode(.inline)
            #if DEBUG
            .modifier(DebugMenuDestination())
            #endif
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
            followUp = model.followUpDelay
            showsNames = model.showsNamesInReminders
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
        case .notAllowed: "Test not sent. Notifications are off for Maru."
        case .noRoom: "Test not sent. Your iPhone can’t hold more reminders."
        case .failed: "Test not sent. Try again."
        }
    }
}
