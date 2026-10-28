import SwiftUI
import WidgetKit

@main
struct MaruWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TakeNowWidget()
        LastDoseWidget()
        // The Live Activity of Maru Pro (D110). The app starts it.
        NextDoseLiveActivity()
    }
}
