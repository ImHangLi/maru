import Foundation
import MaruCore
import MaruDatabase
import Observation
import os

enum AppTab: Hashable {
    case today, myList
}

/// The state of the app shell. The views read it and call its operations. They do not get the store (spec 6).
@MainActor
@Observable
final class AppModel {
    enum Content: Equatable, Sendable {
        /// The first read runs. The page stays empty, with no logo and no progress view (spec 9).
        case loading
        case loaded(Snapshot)
        /// The database did not open, or a read failed. The files stay as they are, and the app shows
        /// no empty list in their place (spec 7.3, T37).
        case failed(StorageError)
    }

    /// A return after more time than this in the background is a new session (spec 1).
    static let sessionTimeout = Duration.seconds(30 * 60)

    /// Only the files of the model change it. The views read it.
    var content = Content.loading
    /// A new process starts on Today (spec 1).
    var selectedTab = AppTab.today

    /// The edit screen that is open, if any (spec 3 P03). `AppModel+Editor.swift` has its operations.
    var editor: EditorSession?
    /// What the system holds for each schedule after the last run of the reminder engine. The item detail
    /// shows it (T03). `AppModel+Detail.swift` has its operations.
    var reminderStatus: [ScheduleID: ReminderStatus] = [:]
    /// The reminders that failed with a save or a change and wait for their alert, the oldest first (D028).
    /// Two results can wait, because a save closes the edit screen before its reminder run ends.
    var reminderAlerts: [ReminderAlert] = []
    /// An archive or a delete that waits for its one confirmation (D033). `AppModel+Detail.swift` has its operations.
    var endRequest: ItemEndRequest?
    /// A confirmed archive or delete failed. The store is unchanged.
    var endFailed = false

    /// Only the operations of the model use the store. A view calls an operation (spec 6).
    let store: AppStore
    /// The state of the Today page that is not in the store. See `AppModel+Today.swift`.
    var today = TodayState()
    /// The history page, open over Today. See `AppModel+History.swift`.
    var history = HistoryState()
    /// The state of the settings sheet. See `AppModel+Settings.swift`.
    var settings = SettingsState()
    /// The state of "Your Data" in settings. See `AppModel+Backup.swift`.
    var transfer = DataTransferState()
    /// Counts the restores (D040). A read or an operation that started before a restore changes nothing
    /// in the model when it ends, because its IDs and values can belong to the replaced data.
    var dataGeneration = 0
    /// The first time of day of each item with an active plan, for the order of My Items. `nil` before the
    /// first read. See `MyListView.swift`.
    var listTimes: [ItemID: WallClockTime]?
    #if DEBUG
    /// A one-time result of the debug tool on Today, for example after a reset. See `App/Debug/`.
    var debugNotice: DebugMessage?
    #endif
    private var load: Task<Void, Never>?
    /// A refresh request came while a read ran. The model reads again when that read ends.
    private var needsRefresh = false
    /// A launch, a return, or a clock or time zone change asks for one reminder run after the next read.
    /// A save runs the engine by itself, and a record refreshes only the follow-ups.
    private var needsReconcile = true
    private var backgroundedAt: ContinuousClock.Instant?
    private var launch: OSSignpostIntervalState?

    init() {
        store = AppStore()
        launch = Signposts.signposter.beginInterval("Launch")
        // A file of the share sheet stays when the app stops before the sheet closes (spec 10).
        Task.detached(priority: .background) { [store] in store.removeExports() }
        #if DEBUG
        // Applies a request of the debug menu before the first read opens a store.
        if let problem = DebugStore.launch.problem { debugNotice = DebugMessage(text: problem, isProblem: true) }
        if let tab = DebugLaunch.tab { selectedTab = tab }
        debugOpenSettings()
        #endif
    }

    /// Damage, a newer schema, and a failed migration stay the same for a second try in one process.
    /// Each other failure, for example a locked device, can end.
    var canRetry: Bool {
        switch content {
        case .failed(.corrupt), .failed(.newerSchema), .failed(.migrationFailed): false
        default: true
        }
    }

    /// The launch path, and each later read: open the database, read today, build the projection, show it (spec 9).
    ///
    /// It waits for nothing else: no network, no analytics, no StoreKit, and no image work (T35).
    func refresh() {
        guard canRetry else { return }
        let now = Date()
        let deviceTimeZone = NamedTimeZone(device: .current, at: now)
        // The content of another day must not show as today while the read runs (spec 9).
        if case let .loaded(snapshot) = content, !snapshot.isCurrent(at: now, deviceTimeZone: deviceTimeZone) {
            content = .loading
        }
        // One read runs at a time, so an older result never comes after a newer one.
        guard load == nil else {
            needsRefresh = true
            return
        }
        // A detached task starts at once. A task of the main actor starts when the main thread is free,
        // and at launch that is after the system builds the first frame.
        let generation = dataGeneration
        load = Task.detached { [store] in
            let content: Content
            do throws(StorageError) {
                #if DEBUG
                if let deviceTimeZone, let problem = await store.seedLaunchScenario(at: now, deviceTimeZone: deviceTimeZone) {
                    await self.showDebugNotice(DebugMessage(text: problem, isProblem: true))
                }
                if DebugLaunch.wantsSampleData, let deviceTimeZone {
                    try? await store.loadSampleData(at: now, deviceTimeZone: deviceTimeZone)
                }
                #endif
                content = .loaded(try await store.snapshot(at: now, deviceTimeZone: deviceTimeZone))
            } catch {
                content = .failed(error)
            }
            await self.show(content, generation: generation)
        }
    }

    private func show(_ content: Content, generation: Int) {
        load = nil
        // A read that started before a restore shows the replaced data. Read again.
        guard generation == dataGeneration else {
            needsRefresh = false
            return refresh()
        }
        var content = content
        if case var .loaded(snapshot) = content, snapshot.today != nil {
            snapshot.today?.apply(heldRecords)
            content = .loaded(snapshot)
        }
        // The day or the time zone can change while the read runs, also in the background.
        // Such a result does not show as today (spec 9), and the model reads again.
        let now = Date()
        var isCurrent = true
        if case let .loaded(snapshot) = content {
            isCurrent = snapshot.isCurrent(at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now))
        }
        if isCurrent {
            let replacesToday = if case let .loaded(shown) = self.content { shown.today != nil } else { false }
            self.content = content
            todayDidShow(replacesToday: replacesToday)
            // After the content shows, so Today never waits for the reminders (spec 8.1, 9).
            if case .loaded = content, needsReconcile, let deviceTimeZone = NamedTimeZone(device: .current, at: now) {
                needsReconcile = false
                reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
            }
            #if DEBUG
            if let deviceTimeZone = NamedTimeZone(device: .current, at: now) {
                debugTap(at: now, deviceTimeZone: deviceTimeZone)
            }
            if DebugLaunch.history != nil, !DebugLaunch.didOpenHistory {
                DebugLaunch.didOpenHistory = true
                openHistory()
            }
            #endif
        }
        if needsRefresh || !isCurrent {
            needsRefresh = false
            refresh()
        }
    }

    /// A read that runs can start before a commit and show the state before it. Read again when it ends.
    func refreshAfterRunningRead() {
        if load != nil { needsRefresh = true }
    }

    /// The Today page calls this when it shows the content of a snapshot. The first call ends the launch.
    func todayContentDidAppear() {
        guard let launch else { return }
        self.launch = nil
        Signposts.signposter.endInterval("Launch", launch)
        if let milliseconds = Signposts.millisecondsSinceProcessStart() {
            Signposts.signposter.emitEvent("FirstTodayContent", "\(milliseconds) ms since process start")
        }
    }

    func didEnterBackground() {
        backgroundedAt = .now
        today.focus = nil
    }

    #if DEBUG
    /// `-MaruTap`: one tap after the first read of the process.
    private func debugTap(at now: Date, deviceTimeZone: NamedTimeZone) {
        guard !DebugLaunch.didTap else { return }
        DebugLaunch.didTap = true
        Task {
            if let reminder = await store.debugTap(at: now, deviceTimeZone: deviceTimeZone) {
                openReminder(reminder)
            }
        }
    }
    #endif

    /// Runs the reminder engine, then the follow-ups. It never asks for permission here. Only a confirmed save
    /// asks (spec 2.2). A failed run changes nothing, and the next launch, return, or save runs again.
    private func reconcileReminders(at now: Date, deviceTimeZone: NamedTimeZone) {
        Task.detached { [store] in
            let outcome = try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone)
            await self.reminderRunDidEnd(outcome)
            #if DEBUG
            await self.debugReconcileDidEnd(outcome)
            await store.reconcileAfterLateClear()
            #endif
        }
    }

    /// A clock change, a new time zone, or a midnight in the device zone. A device-following series and its
    /// follow-ups move with the zone (spec 8.1).
    func timeDidChange() {
        needsReconcile = true
        refresh()
    }

    /// A short return keeps the page. A return after `sessionTimeout` is a new session and opens Today (spec 1).
    /// Each return reads again, because the day or the time zone can be another one.
    func didBecomeActive() {
        // The user can change the permission in the Settings app while Maru is away (T14).
        readNotificationPermission()
        // The first activation of a process has no time in the background. `refresh` already runs.
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        if ContinuousClock.now - backgroundedAt > Self.sessionTimeout {
            selectedTab = .today
            // A long absence opens Today, never the history (spec 4, T26). Unconfirmed events stay (D014).
            resetHistory()
        } else if history.isOpen {
            // The day can be another one.
            loadHistory()
            loadHistoryGraph()
        }
        today.isReturning = true
        needsReconcile = true
        refresh()
    }
}
