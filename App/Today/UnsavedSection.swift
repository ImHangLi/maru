import SwiftUI

/// One retry for every event that the store did not confirm, as the first section of Today and of the history.
///
/// A row can go away before its retry: after an undo, an archive, or a new day. The section stays until each
/// event is saved, so every unconfirmed event has a "Try Again" (D014, T19). It does not block the page.
struct UnsavedSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let count = model.unsavedCount
        if count > 0 {
            Section {
                Button {
                    model.retryUnsaved()
                } label: {
                    LabeledContent {
                        Text("Try Again")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    } label: {
                        Label {
                            Text("\(count) changes not saved")
                                .foregroundStyle(Color.primary)
                                .numberMotion(value: count)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .disabled(model.isRetryingUnsaved)
                .accessibilityLabel(Text("\(count) changes not saved. Try Again"))
            }
        }
    }
}
