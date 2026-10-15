import MaruCore
import SwiftUI

/// The frame of the app: two tabs, or the storage problem in place of them.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    /// The edit screen is on the display, also while it closes. A reminder alert waits for its end.
    @State private var editorIsUp = false
    /// The reminder alert on the display. It is a copy, so a later result does not change it.
    @State private var shownAlert: ReminderAlert?
    @State private var showsAlert = false
    /// The archive or delete confirmation on the display. It is a copy, so the alert keeps its text while it closes.
    @State private var shownEnd: ItemEndRequest?
    @State private var showsEnd = false
    /// The one-time opt-in question about usage statistics in an opt-in region (spec 11.3, D051, D078).
    @State private var showsStatisticsNotice = false
    /// The one-time offer of "Remind Again" after the first save with a time (D091). The item is a copy, so the alert keeps it.
    @State private var shownOffer: ItemID?
    @State private var showsOffer = false

    var body: some View {
        @Bindable var model = model
        Group {
            if case let .failed(error) = model.content {
                StorageProblemView(error: error)
            } else {
                TabView(selection: $model.selectedTab) {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "checkmark.circle") }
                        .tag(AppTab.today)
                    MyListView()
                        .tabItem { Label("My Items", systemImage: "square.grid.2x2") }
                        .tag(AppTab.myList)
                }
                .sheet(item: $model.editor, onDismiss: { editorIsUp = model.editor != nil }) { session in
                    ItemEditorView(session: session)
                }
                .onChange(of: model.editor != nil, initial: true) { _, isOpen in
                    if isOpen { editorIsUp = true }
                }
                .sheet(isPresented: $model.settings.isPresented) { SettingsView() }
            }
        }
        // The storage problem page removes the tabs and their sheet, so `onDismiss` can not run.
        // Without the sheet, the edit screen is not on the display.
        .onChange(of: model.editor != nil) { _, isOpen in
            if !isOpen, storageFailed { editorIsUp = false }
        }
        .onChange(of: storageFailed) { _, _ in
            if model.editor == nil { editorIsUp = false }
        }
        // A tapped reminder while the data is protected. Nothing is recorded (T40).
        .alert(
            "Unlock to Continue",
            isPresented: Binding(get: { model.today.lockedTap != nil }, set: { if !$0 { model.today.lockedTap = nil } })
        ) {
            Button("Try Again") { model.retryLockedTap() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Maru can’t open your records while your iPhone is locked. Unlock it, then try again.")
        }
        // A save or a change shows no message. The list updates in place. Only a failed reminder says so (D028).
        // One alert shows at a time, and the next one comes after the edit screen and the alert before it end.
        // A failure says what went wrong, and "Send Feedback" opens the form of Settings. Nothing is sent by itself (D086).
        .alert(reminderAlertTitle, isPresented: $showsAlert, presenting: shownAlert) { alert in
            Button("OK", role: .cancel) {}
            if alert.kind != .tooMany {
                Button("Send Feedback") {
                    guard let url = FeedbackSection.formURL else { return }
                    model.analytics.capture(.feedbackOpened)
                    openURL(url)
                }
            }
        } message: { alert in
            switch alert.kind {
            case .tooMany: Text("The plan is saved. It has too many times for iPhone.")
            case .notSet, .notConfirmed: Text("Your change is saved, but the reminder for this item isn’t set yet.")
            case .mayStillRemind: Text("Your change is saved, but the old reminder may still go off.")
            }
        }
        // The one confirmation of an archive or a delete, for each page that offers it (D033).
        .alert(endTitle, isPresented: $showsEnd, presenting: shownEnd) { request in
            switch request.kind {
            case .archive: Button("Archive", role: .destructive) { model.end(request) }
            case .delete: Button("Delete Item", role: .destructive) { model.end(request) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            switch request.kind {
            case .archive:
                Text("Maru stops its reminders and hides it from Today and My Items. Your records stay. This is not advice to stop taking it.")
            case .delete:
                Text("Maru deletes this item, its plan, and all its records. You can’t undo this.")
            }
        }
        .onChange(of: model.endRequest) { _, request in
            guard let request else { return }
            shownEnd = request
            showsEnd = true
            model.endRequest = nil
        }
        .alert("Not Changed", isPresented: $model.endFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Maru couldn’t save this change. Try again.")
        }
        // The offer of "Remind Again" waits for the edit screen and for the alerts before it. It changes nothing by itself.
        .onChange(of: offerIsDue, initial: true) { _, isDue in
            guard isDue, let itemID = model.remindAgainOffer else { return }
            shownOffer = itemID
            showsOffer = true
            model.remindAgainOffer = nil
        }
        .alert("Remind Again?", isPresented: $showsOffer) {
            Button("Turn On") {
                if let shownOffer { model.turnOnRemindAgain(for: shownOffer) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Maru can remind you again up to 2 times, 30 minutes apart, if you don’t record a dose.")
        }
        // The opt-in question waits for the edit screen and for the alerts before it.
        .onChange(of: noticeIsDue, initial: true) { _, isDue in
            guard isDue else { return }
            showsStatisticsNotice = true
            model.analyticsNoticeDidShow()
        }
        .alert("Help Improve Maru?", isPresented: $showsStatisticsNotice) {
            Button("Share Statistics") { model.setSharesUsageStatistics(true) }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Share how you use the app, such as whether you recorded a dose today. Maru never shares item names, doses, or times. You can change this in Settings.")
        }
        .onChange(of: nextAlert) { _, alert in
            guard let alert else { return }
            shownAlert = alert
            showsAlert = true
            model.reminderAlertDidShow(alert.id)
        }
    }

    /// The oldest result that waits, when the display is free for its alert.
    private var nextAlert: ReminderAlert? {
        editorIsUp || showsAlert || showsStatisticsNotice ? nil : model.reminderAlerts.first
    }

    private var offerIsDue: Bool {
        model.remindAgainOffer != nil && !model.analyticsNotice && !editorIsUp && !showsAlert && !showsEnd
            && !showsStatisticsNotice && !showsOffer && model.reminderAlerts.isEmpty && !model.settings.isPresented
    }

    private var noticeIsDue: Bool {
        model.analyticsNotice && !editorIsUp && !showsAlert && !showsEnd && !showsStatisticsNotice && !showsOffer
            && model.reminderAlerts.isEmpty && !model.settings.isPresented
    }

    private var storageFailed: Bool {
        if case .failed = model.content { true } else { false }
    }

    private var endTitle: Text {
        guard let shownEnd else { return Text(verbatim: "") }
        return switch shownEnd.kind {
        case .archive: Text("Archive \(shownEnd.name)?")
        case .delete: Text("Delete \(shownEnd.name)?")
        }
    }

    private var reminderAlertTitle: Text {
        switch shownAlert?.kind {
        case .mayStillRemind: Text("Reminders May Still Be On")
        default: Text("Reminder Not Set")
        }
    }
}
