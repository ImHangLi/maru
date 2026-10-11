import SwiftUI

/// The line under the name of an item whose reminders are off, on Today and My Items (T07).
struct RemindersOffLabel: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: "bell.slash")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text("Reminders off")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}
