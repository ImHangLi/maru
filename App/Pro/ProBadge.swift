import SwiftUI

/// The quiet "PRO" mark beside an entry of Maru Pro, for a free user only (D133). A Pro user sees nothing. A tap on the row
/// keeps its own action, which opens the paywall with the source of the entry.
///
/// "PRO" is a brand mark and stays in English. VoiceOver reads "Maru Pro" as a part of the row, not as an element of its own.
struct ProBadge: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.pro.isPro {
            Text(verbatim: "PRO")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: .capsule)
                .accessibilityLabel(Text("Maru Pro"))
        }
    }
}

/// The title of a row with no value, and the badge at its trailing edge.
struct ProRowTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            ProBadge()
        }
    }
}
