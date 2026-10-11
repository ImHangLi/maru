#if DEBUG
import SwiftUI

// The text here is not product copy. It uses `String` and `Text(verbatim:)`, so it stays out of the
// String Catalog and out of a release build.

/// The last section of the settings sheet in a debug build.
struct DebugSection: View {
    var body: some View {
        Section {
            NavigationLink {
                DebugMenuView()
            } label: {
                LabeledContent {
                    Text(DebugStore.launch.scenario?.title ?? "Real store")
                } label: {
                    Text(verbatim: "Test Scenarios")
                }
            }
        } header: {
            Text(verbatim: "Debug")
        } footer: {
            Text(verbatim: "Debug builds only. Scenarios use a separate debug store with made-up items.")
        }
    }
}

/// `-MaruSettings debug` opens the debug menu at launch, for screenshots.
struct DebugMenuDestination: ViewModifier {
    @State private var isPresented = DebugLaunch.settings == "debug"

    func body(content: Content) -> some View {
        content.navigationDestination(isPresented: $isPresented) { DebugMenuView() }
    }
}

/// The test-data tool of spec 14 A. A load or a reset closes the app, and the next launch uses the other store.
struct DebugMenuView: View {
    @Environment(AppModel.self) private var model
    @State private var message: DebugMessage?
    /// The refused request that Try Again asks again.
    @State private var retry: DebugStoreRequest?
    /// The scenario that waits for the confirmation of the load.
    @State private var pending: DebugScenario?
    /// The request that waits for the "closes now" alert.
    @State private var closing: DebugStoreRequest?
    /// A scenario that only lists steps. It is shown, and nothing is loaded.
    @State private var steps: DebugScenario?

    private var loaded: DebugScenario? { DebugStore.launch.scenario }

    var body: some View {
        Form {
            if let shown = steps ?? loaded {
                Section {
                    ForEach(shown.checks, id: \.self) { check in
                        Label { Text(verbatim: check) } icon: { Image(systemName: "checkmark.circle") }
                    }
                } header: {
                    Text(verbatim: (shown.loadsData ? "Loaded: " : "Steps: ") + shown.title)
                }
            }
            if let message {
                Section {
                    Text(verbatim: message.text).foregroundStyle(message.isProblem ? .red : .primary)
                    if message.canRetry, let retry {
                        Button { ask(retry) } label: { Text(verbatim: "Try Again") }
                    }
                }
            }
            Section {
                ForEach(DebugScenario.allCases) { scenario in
                    Button {
                        message = nil
                        if scenario.loadsData {
                            pending = scenario
                        } else {
                            steps = scenario
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: scenario.title)
                            Text(verbatim: scenario.summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(verbatim: "Scenarios")
            } footer: {
                Text(verbatim: "A load replaces the test data, then Maru closes. For automation, launch with -MaruScenario and a name: "
                    + DebugScenario.allCases.filter(\.loadsData).map(\.rawValue).joined(separator: ", ") + ".")
            }
            Section {
                Button(role: .destructive) {
                    ask(.reset)
                } label: {
                    Text(verbatim: "Reset Debug Data")
                }
                .disabled(loaded == nil)
            } footer: {
                Text(verbatim: loaded == nil
                    ? "The app uses your real list. A reset never changes it."
                    : "Maru closes. The next launch deletes the test data and the entries made with it, then goes back "
                        + "to your real list and sets your real reminders again. Your real list stays as it is.")
            }
        }
        .navigationTitle(Text(verbatim: "Test Scenarios"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            Text(verbatim: "Load Test Data?"),
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { scenario in
            Button {
                ask(.load(scenario))
            } label: {
                Text(verbatim: "Load")
            }
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        } message: { _ in
            Text(verbatim: "Your real reminders pause while test data is active. "
                + "They come back when you tap Reset Debug Data. Your real list stays as it is.")
        }
        .alert(
            Text(verbatim: "Maru Closes Now"),
            isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } }),
            presenting: closing
        ) { request in
            Button {
                close(request)
            } label: {
                Text(verbatim: "Close Maru")
            }
            Button(role: .cancel) {} label: { Text(verbatim: "Cancel") }
        } message: { request in
            Text(verbatim: request == .reset
                ? "Maru closes now. Open it again to return to your real list."
                : "Maru closes now. Open it again to use test data.")
        }
    }

    /// Refuses at once while a change is not saved. Else the alert says that Maru closes.
    private func ask(_ request: DebugStoreRequest) {
        message = model.debugStoreRefusal
        retry = message == nil ? nil : request
        if message == nil { closing = request }
    }

    /// The store of a process never changes, so the request takes effect at the next launch.
    private func close(_ request: DebugStoreRequest) {
        // A record can start between the alert and the tap. Then the app stays open and says why.
        message = model.closeForDebugStore(request)
        retry = message == nil ? nil : request
    }
}
#endif
