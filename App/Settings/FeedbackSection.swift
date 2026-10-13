import SwiftUI

/// The way to send a message to the makers (D037). The form is a web page of Tally.
/// Maru sends nothing by itself: the page opens only after a tap, and it gets no data of the app.
struct FeedbackSection: View {
    /// The public feedback form.
    static let formURL = URL(string: "https://tally.so/r/jadWkR")

    @Environment(\.openURL) private var openURL
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            Button("Send Feedback") {
                guard let url = Self.formURL else { return }
                model.analytics.capture(.feedbackOpened)
                // The system shows the page in a browser sheet over Maru where it can. On an older system, Safari opens.
                if #available(iOS 26.0, *) {
                    openURL(url, prefersInApp: true)
                } else {
                    openURL(url)
                }
            }
            .rowText()
        } footer: {
            Text("The form opens a web page, and we read every message.")
        }
    }
}
