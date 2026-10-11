import MaruCore
import MaruNotifications
import SwiftUI
import UserNotifications

@main
struct MaruApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    private let tapDelegate: ReminderTapDelegate

    init() {
        let model = AppModel()
        // Start the launch path here, so the database opens while the system builds the first view.
        model.refresh()
        _model = State(initialValue: model)
        // Before the launch ends, so a tap that starts the app reaches the model.
        #if DEBUG
        tapDelegate = ReminderTapDelegate(
            open: { [weak model] in model?.openReminder($0) },
            take: { [weak model] in await model?.takeReminder($0) },
            showToday: { [weak model] in model?.selectedTab = .today }
        )
        #else
        tapDelegate = ReminderTapDelegate(
            open: { [weak model] in model?.openReminder($0) },
            take: { [weak model] in await model?.takeReminder($0) }
        )
        #endif
        UNUserNotificationCenter.current().delegate = tapDelegate
        // The "Taken" action of a reminder for one item (D034). The call does not wait for the system.
        ReminderAction.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // The user picks the app color in settings. Pink is the default (D025).
                .tint(appColor.tint)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: model.didEnterBackground()
            case .active:
                model.didBecomeActive()
                // The user sees the state in Maru now.
                ActionNotice.clear()
            default: break
            }
        }
    }
}
