import MaruCore
import MaruNotifications
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct MaruApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: AppModel
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    private let tapDelegate: ReminderTapDelegate

    init() {
        let model = AppModel.shared
        // Start the launch path here, so the database opens while the system builds the first view.
        model.refresh()
        _model = State(initialValue: model)
        // Before the launch ends, so a tap that starts the app reaches the model.
        #if DEBUG
        tapDelegate = ReminderTapDelegate(
            open: { [weak model] in model?.openReminder($0) },
            act: { [weak model] in await model?.performReminderAction($0, on: $1) },
            showToday: { [weak model] in model?.selectedTab = .today }
        )
        #else
        tapDelegate = ReminderTapDelegate(
            open: { [weak model] in model?.openReminder($0) },
            act: { [weak model] in await model?.performReminderAction($0, on: $1) }
        )
        #endif
        UNUserNotificationCenter.current().delegate = tapDelegate
        // The actions of a reminder (D034, D090). The call does not wait for the system.
        ReminderAction.register()
        // A tap on a gray capsule of the "Record Dose" widget runs in this process (D048).
        TakeDoseHook.install { try await AppModel.shared.takeFromWidget($0) }
        // The Watch app sends its requests to this process, also in the background (D071).
        WatchLink.shared.start()
        // The rating prompt never asks in the first days after the first launch (D102).
        ReviewPrompt.noteLaunch()
        // The widgets read the tint from the App Group.
        AppGroup.appColor = UserDefaults.standard.string(forKey: DisplaySetting.appColor).flatMap(ItemColor.init) ?? .pink
        #if DEBUG
        if DebugLaunch.wantsFirstRun { UserDefaults.standard.removeObject(forKey: Onboarding.seenKey) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                // The user picks the app color in settings. Pink is the default (D025).
                .tint(appColor.tint)
                .onOpenURL { model.openWidgetLink($0) }
                // After the first frame, so the launch path does not wait for TipKit (spec 9, D103).
                .task { FirstUseTips.configure() }
                .onChange(of: appColor) { _, color in
                    AppGroup.appColor = color
                    WidgetCenter.shared.reloadAllTimelines()
                    model.sendWatchDay()
                }
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
