import SwiftUI

extension View {
    /// Covers a large title while it scrolls under the bar buttons. Apply it to the scroll view of a page with
    /// a large title and a button at the top left.
    ///
    /// On iOS 26 and later, the system shows no scroll edge effect until the large title collapses, so the title
    /// shows through the buttons on its way. The hard style of the system edge effect is on from the first point
    /// of the scroll, and it blurs the title under the bar. Before iOS 26 the large title is part of the bar.
    @ViewBuilder
    func largeTitleCover() -> some View {
        if #available(iOS 26, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
