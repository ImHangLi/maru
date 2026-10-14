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
            // The rows and the footer of "Reminders" come and go with the permission (D030).
            .motion(.layout, value: model.settings.permission)
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
            showsNames = model.showsNamesInReminders
            sharesStatistics = model.sharesUsageStatistics
        }
        // A return from the Settings app shows the new permission (T14).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.readNotificationPermission() }
        }
    }
}

/// The honest reminder state and the way to fix it (spec 2.2, T13, T14).
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
                .rowText()
            }
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
