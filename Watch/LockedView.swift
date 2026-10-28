import SwiftUI

/// The screen of a free user (D111). It says what the Watch app does and that Maru Pro unlocks it on the iPhone.
/// The Watch sells nothing: the button only asks the iPhone to show Maru Pro the next time that Maru is in front.
struct LockedView: View {
    @Environment(WatchModel.self) private var model
    let tint: Color

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Maru Pro")
                    .font(.headline)
                    .foregroundStyle(tint)
                Text("See and record today’s doses on your wrist.")
                    .font(.footnote)
                Text("Unlock with Maru Pro on your iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                // After the iPhone has the request, the text replaces the button. With no reply, the button stays.
                if model.proRequest == .sent {
                    Text("Sent. Open Maru on your iPhone to see Maru Pro.")
                        .font(.footnote)
                        .foregroundStyle(tint)
                } else {
                    Button("Open on iPhone") { model.showProOnPhone() }
                        .tint(tint)
                        .disabled(model.proRequest == .sending)
                    if model.proRequest == .notSent {
                        Text("Your iPhone is not reachable. Open Maru on your iPhone to see Maru Pro.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }
}
