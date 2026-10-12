import SwiftUI

/// The gear button at the top left of both tabs. It opens the settings sheet (D020).
struct SettingsButton: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Settings", systemImage: "gearshape") { model.openSettings() }
        }
    }
}

/// A list row on Today while notifications are off. It does not block the page, and Maru does not
/// ask for the permission again. A tap opens settings (spec 2.2, T13, T14).
struct NotificationsOffSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if model.settings.permission == .denied {
            Section {
                Button { model.openSettings() } label: {
                    NotificationsOffLabel()
                }
                .accessibilityHint(Text("Opens settings"))
            }
        }
    }
}

/// The words of the notice while notifications are off. Today and My Items use it. Like the line
/// "Reminders off", it states the state in the text color with a symbol (design principle 6).
struct NotificationsOffLabel: View {
    var body: some View {
        Label("Notifications off", systemImage: "bell.slash")
            .foregroundStyle(Color.primary)
    }
}
