import SwiftUI
import TipKit

/// The first-use tips (D103). Each shows once, at the moment that its feature is first on the display.
/// TipKit keeps the state in its own store in the app container, not in the health database.
enum FirstUseTips {
    /// Called after the first frame, so the launch path does not wait for the TipKit store (spec 9).
    @MainActor static func configure() {
        #if DEBUG
        if DebugLaunch.wantsFirstRun { try? Tips.resetDatastore() }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }
}

/// On the record circle of the first row of Today.
struct RecordTip: Tip {
    var title: Text { Text("Record a Dose") }
    var message: Text? { Text("Tap the circle when you take it. Tap it again to change or undo the record.") }
    var image: Image? { Image(systemName: "checkmark.circle") }
}

/// On the first tile of My Items.
struct ItemMenuTip: Tip {
    var title: Text { Text("More for Each Item") }
    var message: Text? { Text("Touch and hold an item to edit, archive, or delete it.") }
    var image: Image? { Image(systemName: "hand.tap") }
}

extension View {
    /// The popover of the tip, only when `shows` is true. Before iOS 26, `popoverTip` takes no optional tip.
    @ViewBuilder func popoverTip(_ tip: some Tip, when shows: Bool) -> some View {
        if shows { popoverTip(tip) } else { self }
    }
}

extension EnvironmentValues {
    /// No sheet, alert, or onboarding is on the display or waits for it. A tip popover and an alert must not
    /// show at the same time, because UIKit presents only one of them. `RootView` sets it.
    @Entry var tipsMayShow = false
}
