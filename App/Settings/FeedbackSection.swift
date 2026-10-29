import SwiftUI

/// The last group of the settings root: "Send Feedback" and "About" (D135).
///
/// Feedback goes to a web page of Tally (D037). Maru sends nothing by itself: the page opens only after a tap, and it gets
/// no data of the app.
struct FeedbackSection: View {
    /// The public feedback form.
    static let formURL = URL(string: "https://tally.so/r/jadWkR")

    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            Button { Self.open(model: model, openURL: openURL) } label: {
                SettingsRowLabel("Send Feedback", systemImage: "bubble.left")
            }
            NavigationLink(value: SettingsPage.about) {
                SettingsRowLabel("About", systemImage: "info.circle")
            }
        } footer: {
            Text("Opens a web page. We read every message.")
        }
    }

    /// Opens the form in Safari, as for the links in About. An in-app browser over the settings sheet did not open.
    static func open(model: AppModel, openURL: OpenURLAction) {
        guard let url = formURL else { return }
        model.analytics.capture(.feedbackOpened)
        openURL(url)
    }
}
