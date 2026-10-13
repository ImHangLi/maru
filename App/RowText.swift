import SwiftUI

/// The text of a row that is an action or a link. It has the text color, not the app tint, so the row does
/// not look like a warning (D076). A row that is off is gray, as the system draws it.
private struct RowText: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content.foregroundStyle(isEnabled ? Color.primary : Color(.tertiaryLabel))
    }
}

extension View {
    func rowText() -> some View { modifier(RowText()) }
}

/// A row with a symbol: the symbol keeps the app tint, and the title has the text color (D076).
struct RowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title.rowText()
        } icon: {
            configuration.icon
        }
    }
}
