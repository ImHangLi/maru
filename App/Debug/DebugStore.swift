#if DEBUG
import Foundation
import MaruCore
import MaruNotifications
import UserNotifications

/// The separate store of the debug scenarios. A debug build only.
///
/// A scenario never writes the real database or the real drafts. It writes `Application Support/DebugDatabase/`
/// and `Application Support/DebugDrafts/`, and the app uses them until "Reset Debug Data". A reset deletes only
/// those directories (spec 7.3).
///
/// The store is chosen one time, at launch, and it never changes while the process runs. The debug menu only
/// writes a request and closes the app. The next launch applies the request before anything opens a store.
enum DebugStore {
    static let root = URL.applicationSupportDirectory.appending(path: "DebugDatabase", directoryHint: .isDirectory)
    static let draftsRoot = URL.applicationSupportDirectory.appending(path: "DebugDrafts", directoryHint: .isDirectory)

    /// The raw value of the loaded `DebugScenario`. A value means that the app uses the debug store.
    private static let scenarioKey = "debug.scenario"
    /// A request of the debug menu for the next launch: the raw value of a scenario, or `reset`.
    private static let requestKey = "debug.request"
    private static let resetRequest = "reset"
    /// The real preferences at the switch to the debug store. A reset puts them back, so a demo change never stays.
    private static let preferenceBackupKey = "debug.preferenceBackup"
    /// The instant of the latest store change. It stays after this launch, so a later launch knows it too.
    private static let transitionKey = "debug.transitionDate"
    /// The longest wait for the removal of the pending requests at a store change.
    static let clearWait = Duration.seconds(3)
    /// Every key that a debug scenario can change and that a reset must put back (D023). The follow-up setting
    /// moved from a key to the items (D079), so no key is left. Add a key here when a scenario writes one.
    private static let preferenceKeys: [String] = []

    /// What this launch did. The first use applies the request, so each read of the store directory comes after it.
    static let launch = applyLaunchRequest()

    /// The debug store directory while a scenario is loaded, else `nil` for the real store.
    static var directory: URL? {
        launch.scenario == nil ? nil : root
    }

    /// The draft directory of the debug store while a scenario is loaded, else `nil` for the real drafts.
    static var drafts: URL? {
        launch.scenario == nil ? nil : draftsRoot
    }

    /// Asks the next launch to load `scenario` into a new debug store. The caller then closes the app.
    static func requestLoad(_ scenario: DebugScenario) {
        UserDefaults.standard.set(scenario.rawValue, forKey: requestKey)
    }

    /// Asks the next launch to delete the debug store and to use the real store. The caller then closes the app.
    static func requestReset() {
        UserDefaults.standard.set(resetRequest, forKey: requestKey)
    }

    struct Launch: Sendable {
        /// The scenario of the debug store that this process uses, or `nil` for the real store.
        var scenario: DebugScenario?
        /// The scenario to write into the new, empty debug store before the first read.
        var seed: DebugScenario?
        /// This launch deleted the debug store and went back to the real store.
        var didReset = false
        /// A failed request, for the debug notice on Today.
        var problem: String?
        /// The instant when this launch changed the store, else `nil`. The notification queue then clears first.
        var transitionDate: Date?
    }

    /// The instant of the latest store change, in this launch or an earlier one.
    static var transitionDate: Date? {
        _ = launch
        return UserDefaults.standard.object(forKey: transitionKey) as? Date
    }

    /// A notification delivered before the latest store change belongs to the other store, so a tap must not
    /// resolve it against this one.
    static func precedesTransition(_ date: Date) -> Bool {
        transitionDate.map { date < $0 } ?? false
    }

    /// Removes the delivered and the pending notifications of both stores. The app runs it as the first update of
    /// its notification queue, so no engine adds a request before it. The removal is asynchronous, so it reads
    /// the pending requests until none is left, at most for `clearWait`.
    /// Cost: the user also loses the delivered Maru notifications in Notification Center at each switch.
    /// - Returns: `false` when a request was still pending at the deadline.
    static func clearNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        let reader = SystemReminderCenter()
        let deadline = ContinuousClock.now + clearWait
        while ContinuousClock.now < deadline {
            if await reader.pendingRequests().isEmpty { return true }
            try? await Task.sleep(for: ReminderEngine.removalWait)
        }
        return false
    }

    /// Runs one time, before any store opens. A menu request comes first, then `-MaruScenario`.
    /// When a deletion fails, the selection stays as it was, so test data never mixes with the real list.
    private static func applyLaunchRequest() -> Launch {
        let defaults = UserDefaults.standard
        var launch = Launch(scenario: defaults.string(forKey: scenarioKey).flatMap(DebugScenario.init))
        let request = defaults.string(forKey: requestKey)
        defaults.removeObject(forKey: requestKey)
        if request == resetRequest {
            do {
                try deleteFiles()
                defaults.removeObject(forKey: scenarioKey)
                restorePreferences()
                launch.transitionDate = recordTransition()
                launch.scenario = nil
                launch.didReset = true
            } catch {
                launch.problem = "The test data was not deleted, so the app still uses it: \(error)"
            }
        } else if let scenario = request.flatMap(DebugScenario.init) ?? DebugLaunch.scenario, scenario.loadsData {
            do {
                try deleteFiles()
                // A load over a loaded scenario keeps the backup of the real preferences.
                if launch.scenario == nil { backUpPreferences() }
                defaults.set(scenario.rawValue, forKey: scenarioKey)
                launch.transitionDate = recordTransition()
                launch.scenario = scenario
                launch.seed = scenario
            } catch {
                launch.problem = "The scenario did not load: \(error)"
            }
        }
        return launch
    }

    /// Saves each preference key as it is. A key with no value stays out of the backup, so it means "not set".
    private static func backUpPreferences() {
        let defaults = UserDefaults.standard
        var backup: [String: Any] = [:]
        for key in preferenceKeys {
            if let value = defaults.object(forKey: key) { backup[key] = value }
        }
        defaults.set(backup, forKey: preferenceBackupKey)
    }

    /// Puts back the real preferences exactly, then deletes the backup. With no backup, nothing changes.
    private static func restorePreferences() {
        let defaults = UserDefaults.standard
        guard let backup = defaults.dictionary(forKey: preferenceBackupKey) else { return }
        for key in preferenceKeys {
            if let value = backup[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        defaults.removeObject(forKey: preferenceBackupKey)
    }

    private static func recordTransition() -> Date {
        let now = Date()
        UserDefaults.standard.set(now, forKey: transitionKey)
        return now
    }

    private static func deleteFiles() throws {
        for directory in [root, draftsRoot] where FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: directory)
        }
    }
}

/// The debug state of `AppStore`.
struct DebugStoreState {
    /// The next record commits, then fails with `unavailable` (the "failed write" scenario).
    /// Only the seed of that scenario sets it, so it never acts on the real store.
    var failsNextRecord = false
    /// The launch seed runs one time in a process.
    var didSeed = false
    /// The tap of the seeded scenario. `AppStore.debugTap` delivers it after the first read.
    var launchTap: DeliveredReminder?
    /// The clear of the notifications at a store change. The first launch reconcile reads its result.
    var notificationClear: Task<Bool, Never>?
}
#endif
