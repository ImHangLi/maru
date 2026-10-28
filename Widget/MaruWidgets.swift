import SwiftUI
import WidgetKit

@main
struct MaruWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TakeNowWidget()
        LastDoseWidget()
        NextDoseWidget()
    }
}
