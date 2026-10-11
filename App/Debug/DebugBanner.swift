#if DEBUG
import SwiftUI

/// A yellow band at the top of each data screen while the app uses the debug store, so test data never looks
/// like the real list. Not product copy: `Text(verbatim:)` keeps it out of the String Catalog.
struct DebugDataBanner: ViewModifier {
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            // The store of a process never changes, so the band never changes while the app runs.
            if DebugStore.launch.scenario != nil {
                Label {
                    Text(verbatim: "Test data — not your real list. Reset in Settings deletes entries made now.")
                } icon: {
                    Image(systemName: "testtube.2")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.yellow)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The one-time result of a launch that applied a request of the debug menu, on Today.
struct DebugNoticeAlert: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content.alert(
            Text(verbatim: model.debugNotice?.isProblem == true ? "Debug Data Problem" : "Debug Data"),
            isPresented: Binding(get: { model.debugNotice != nil }, set: { if !$0 { model.debugNotice = nil } }),
            presenting: model.debugNotice
        ) { _ in
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: { notice in
            Text(verbatim: notice.text)
        }
    }
}
#endif
