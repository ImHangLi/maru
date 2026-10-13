import SwiftUI

/// Two pages side by side at a regular width, such as an iPad (D072). Each page has its own navigation stack.
/// The first page has the width of an iPhone page, and the second page gets the other space.
struct WideColumns<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .containerRelativeFrame(.horizontal) { width, _ in min(max(width * 0.38, 320), 420) }
            Divider().ignoresSafeArea()
            trailing
        }
    }
}
