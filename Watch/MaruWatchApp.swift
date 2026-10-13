import SwiftUI

/// The Watch app (D071): one screen with the doses of today. The iPhone holds the data and makes each record.
@main
struct MaruWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(model)
        }
    }
}
