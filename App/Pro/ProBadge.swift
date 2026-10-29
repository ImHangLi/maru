import SwiftUI

/// The "PRO" mark right after the title of an entry of Maru Pro, for a free user only (D133, changed by D134). A Pro user
/// sees nothing. A tap on the row keeps its own action, which opens the paywall with the source of the entry.
///
/// "PRO" is a brand mark and stays in English. VoiceOver reads "Maru Pro" as a part of the row, not as an element of its own.
struct ProBadge: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink

    var body: some View {
        if !model.pro.isPro {
            Text(verbatim: "PRO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(appColor.labelOnTint)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(appColor.tint, in: .capsule)
                .accessibilityLabel(Text("Maru Pro"))
        }
    }
}

/// The title of a row with the badge right after it.
struct ProRowTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            ProBadge()
        }
    }
}
