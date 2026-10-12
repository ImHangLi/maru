import SwiftUI

/// The line under the name of a Today row whose reminders are off (T07). A state shows in the text color
/// with its symbol, never in gray (design principle 6).
struct RemindersOffLabel: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "bell.slash")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text("Reminders off")
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
    }
}
