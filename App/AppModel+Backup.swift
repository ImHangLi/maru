import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications

/// The state of "Your Data" in settings (D040).
struct DataTransferState {
    /// A file that waits for the share sheet.
    struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    enum Failure: Equatable {
        case fileNotMade, notABackup, newerBackup, notRestored
        /// The restore replaced the data, and the storage medium did not confirm it.
        case restoredNotConfirmed
    }

    var shared: SharedFile?
    /// A file is in the making, a backup is in the check, or a restore runs. The rows wait.
    var isWorking = false
    /// A restore runs. Settings stays open, and Today and the history record nothing until the model forgets
    /// the replaced data.
    var isRestoring = false
    /// A checked backup that waits for the one confirmation.
    var staged: StagedBackup?
    var failure: Failure?
}

extension AppModel {
    /// "Export Records": makes the CSV file, then the share sheet shows it. Maru sends nothing by itself.
    func exportRecords() {
        share(.export) { store, now in
            guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { throw StorageError.invalidData }
            return try await store.exportRecords(at: now, deviceTimeZone: deviceTimeZone)
        }
    }

    /// "Back Up": makes the backup file with the database and the settings, then the share sheet shows it.
    func backUp() {
        let settings = BackupSettings.current()
        share(.backup) { store, now in
            try await store.backUp(at: now, settings: settings)
        }
    }

    private func share(_ action: AnalyticsEvent.DataAction, _ make: @escaping @Sendable (AppStore, Date) async throws -> URL) {
        guard !transfer.isWorking else { return }
        transfer.isWorking = true
        Task { [store] in
            do {
                transfer.shared = DataTransferState.SharedFile(url: try await make(store, Date()))
                analytics.capture(.dataAction(action, .done))
            } catch {
                transfer.failure = .fileNotMade
                analytics.capture(.dataAction(action, .failed))
            }
            transfer.isWorking = false
        }
    }

    /// The share sheet closed. The file holds health data, so it does not stay (spec 10).
    func shareDidEnd() {
        Task { [store] in
            store.removeExports()
        }
    }

    /// The user picked a file for a restore. The check changes nothing. A file that passes waits for
    /// the confirmation, and each other file gets a plain message (T38).
    func checkBackup(at file: URL) {
        guard !transfer.isWorking else { return }
        transfer.isWorking = true
        Task { [store] in
            // The file picker gives access to a file outside the app only between these two calls.
            let isScoped = file.startAccessingSecurityScopedResource()
            defer {
                if isScoped { file.stopAccessingSecurityScopedResource() }
            }
            do throws(StorageError) {
                transfer.staged = try await store.stage(backup: file)
            } catch {
                transfer.failure = Self.restoreFailure(error)
                noteRestore(Self.restoreFailure(error))
            }
            transfer.isWorking = false
        }
    }

    func cancelRestore() {
        guard let staged = transfer.staged else { return }
        transfer.staged = nil
        analytics.capture(.dataAction(.restore, .cancelled))
        Task { [store] in
            await store.discard(staged)
        }
    }

    /// Runs the confirmed restore: the backup replaces the data, and nothing merges (D040).
    ///
    /// After a failure the old data is in place, and the pages read it again. After a success, the model
    /// forgets the old data before the settings sheet closes, so no row of the old data takes a tap. Then every
    /// page reads the new data, the settings of the backup apply, and one run of the notification queue sets the
    /// reminders of the restored plans (T39). The user confirmed plans with reminders, so this run can ask
    /// for the notification permission, as the run after a save does (spec 2.2).
    ///
    /// A restore that committed is a success, also when the storage medium did not confirm it. Settings then
    /// stays open and says so.
    func restore() {
        guard let staged = transfer.staged, !transfer.isWorking else { return }
        transfer.staged = nil
        transfer.isWorking = true
        transfer.isRestoring = true
        Task { [store] in
            defer { transfer.isWorking = false }
            let result: RestoreResult
            do throws(StorageError) {
                result = try await store.restore(staged)
            } catch {
                transfer.isRestoring = false
                transfer.failure = Self.restoreFailure(error)
                noteRestore(Self.restoreFailure(error))
                refresh()
                return
            }
            forgetReplacedData(generation: result.generation)
            transfer.isRestoring = false
            BackupSettings.apply(staged.settings)
            analytics.capture(.dataAction(.restore, result.isFlushed ? .done : .notConfirmed))
            if result.isFlushed {
                // Today shows the restored data. No message says so (D028).
                settings.isPresented = false
            } else {
                transfer.failure = .restoredNotConfirmed
            }
            selectedTab = .today
            refresh()
            let now = Date()
            guard let deviceTimeZone = NamedTimeZone(device: .current, at: now) else { return }
            reminderRunDidEnd(
                try? await store.reconcileReminders(at: now, deviceTimeZone: deviceTimeZone, mayAskForPermission: true)
            )
            var told = Set<ReminderStatus>()
            for (id, status) in reminderStatus where told.insert(status).inserted {
                report(status, of: id, removes: false)
            }
        }
    }

    /// Forgets what the model keeps about the items and the doses of the database that a restore replaced:
    /// the events that the store did not confirm, the open pages, the kept drafts, and the reminder states.
    private func forgetReplacedData(generation: Int) {
        // Each read and operation that started before ends with no effect. The store refuses each record
        // with the old generation.
        dataGeneration = generation
        content = .loading
        // The day change timer of Today stays: it does not belong to the data.
        var today = TodayState()
        today.dayChange = self.today.dayChange
        self.today = today
        resetHistory()
        // A read of the history that started before the restore does not show.
        history.readCount += 1
        editor = nil
        endRequest = nil
        reminderStatus = [:]
        reminderAlerts = []
        DraftFile.removeAll()
    }

    /// A failed check or restore as one result of the `data_action` event (D077).
    private func noteRestore(_ failure: DataTransferState.Failure) {
        let result: AnalyticsEvent.DataResult = switch failure {
        case .notABackup: .invalidFile
        case .newerBackup: .newerFile
        case .restoredNotConfirmed: .notConfirmed
        case .fileNotMade, .notRestored: .failed
        }
        analytics.capture(.dataAction(.restore, result))
    }

    private static func restoreFailure(_ error: StorageError) -> DataTransferState.Failure {
        switch error {
        case .newerSchema: .newerBackup
        case .corrupt, .invalidData, .migrationFailed: .notABackup
        default: .notRestored
        }
    }
}

/// The settings that a backup carries (D040). They are in `UserDefaults` and not in the database (D014).
/// A key or a value that this version of the app does not know changes nothing.
private enum BackupSettings {
    private static let appColor = "appColor"
    private static let reminderNames = "reminderNames"
    private static let remindAgainMinutes = "remindAgainMinutes"
    private static let remindAgainCount = "remindAgainCount"

    static func current() -> [String: String] {
        let followUp = DefaultsFollowUpSetting().load()
        return [
            appColor: UserDefaults.standard.string(forKey: DisplaySetting.appColor) ?? ItemColor.pink.rawValue,
            reminderNames: DefaultsReminderPrivacy().load().rawValue,
            // 0 means off.
            remindAgainMinutes: String(followUp?.interval.rawValue ?? 0),
            // 0 means "Until Recorded".
            remindAgainCount: String(followUp?.count.rawValue ?? 1),
        ]
    }

    static func apply(_ settings: [String: String]) {
        if let color = settings[appColor].flatMap(ItemColor.init(rawValue:)) {
            UserDefaults.standard.set(color.rawValue, forKey: DisplaySetting.appColor)
        }
        if let privacy = settings[reminderNames].flatMap(ReminderPrivacy.init(rawValue:)) {
            DefaultsReminderPrivacy().save(privacy)
        }
        if let minutes = settings[remindAgainMinutes].flatMap({ Int($0) }) {
            // A missing count means "1 Time", as for an install from before D039.
            let count = settings[remindAgainCount].flatMap { Int($0) }.flatMap(FollowUpCount.init(rawValue:)) ?? .one
            if minutes == 0 {
                DefaultsFollowUpSetting().save(nil)
            } else if let interval = FollowUpInterval(rawValue: minutes) {
                DefaultsFollowUpSetting().save(FollowUpSetting(count: count, interval: interval))
            }
        }
    }
}
