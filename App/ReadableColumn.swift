import SwiftUI

/// The readable column of a wide display, such as an iPad (D065). A page keeps its content in a column in the
/// middle. The margins are safe area, so the scroll view keeps the full width, and a scroll starts in a margin too.
/// A display that is not wider than the column, such as an iPhone or Slide Over, gets no margin.
private struct ReadableColumn: ViewModifier {
    /// The width of the readable content guide of UIKit on an iPad, at the default text size.
    static let width: CGFloat = 672
    @State private var margin: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.horizontal, margin)
            // The frame takes the full width, so the margin never changes the width that gives the margin.
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { margin = max(0, ($0 - Self.width) / 2) }
    }
}

extension View {
    /// Keeps the content of a page in the readable column on a wide display.
    func readableColumn() -> some View { modifier(ReadableColumn()) }
}
