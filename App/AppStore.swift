import Foundation
import MaruCore
import MaruDatabase
import MaruNotifications
import os

/// The database of the process, and the reads that the two tabs need.
///
/// Only `AppModel` uses this type. The actor runs its work outside the main actor (spec 9),
/// and it opens the database one time (D014).
actor AppStore {
    /// The store sets strict file protection on its whole directory (spec 10), so the database has a directory of its own.
    ///
    /// The database lives in the App Group container, so the widgets reach it (D048). A build with no container
    /// keeps it in Application Support, where the earlier builds put it.
    private static let directory = AppGroup.databaseDirectory ?? AppGroup.earlierDatabaseDirectory

    private var opened: LocalStore?
    private var engine: ReminderEngine?
    private var followUps: FollowUpEngine?
    private var alarms: AlarmEngine?
    /// Which items an alarm covers in the run that is going on (D079). Each run sets it again, so no run uses the cover of an earlier run.
    private let cover = OSAllocatedUnfairLock(initialState: AlarmCover.none)
    /// The input of the notification engines: which items an alarm covers in the run that is going on.
    private var coverNow: @Sendable () -> AlarmCover {
        let cover = cover
        return { cover.withLock { $0 } }
    }
    /// The last notification update in the queue. Each update waits for the one before it, so the reminder
    /// engine and the follow-up engine never change the requests at the same time (spec 8.4).
    private var updates: Task<Void, Never>?
    #if DEBUG
    /// The state of the debug scenarios. See `App/Debug/`.
    var debug = DebugStoreState()

    /// After a store change, the clear of the old notifications is the first update in the queue (spec 8.4).
    init() {
        guard DebugStore.launch.transitionDate != nil else { return }
        let clear = Task { await DebugStore.clearNotifications() }
        debug.notificationClear = clear
        updates = Task { _ = await clear.value }
    }
    #endif

    /// The open store. The first call opens the database, and a call after a failed open tries again.
    ///
    /// The open can block on a lock, and on a flush at first launch, so it does not run on the main actor.
    /// A failure leaves the files as they are (spec 7.3, T37).
    func open() throws(StorageError) -> LocalStore {
        if let opened { return opened }
        let interval = Signposts.signposter.beginInterval("OpenDatabase")
        defer { Signposts.signposter.endInterval("OpenDatabase", interval) }
        #if DEBUG
        // A debug scenario uses its own store, so the real database is never changed (spec 7.3).
        let directory = DebugStore.directory ?? Self.directory
        #else
        let directory = Self.directory
        #endif
        // The one-time copy of the database to the container. A failure stops here: an empty database in the
        // container would hide the data that the earlier directory still has (spec 7.3, D048).
        // A debug scenario has its own directory and gets no copy of the real data.
        if let container = AppGroup.databaseDirectory, directory == container {
            try LocalStore.adopt(from: AppGroup.earlierDatabaseDirectory, into: directory)
        }
        let store = try LocalStore(directory: directory)
        // The one-time move of the global follow-up setting of version 1.0 to the items (D079). A failure leaves
        // the setting in place, and the next open tries again. A debug scenario has its own store and leaves it alone.
        if directory == Self.directory, LegacyFollowUpSetting.exists() {
            if let setting = LegacyFollowUpSetting.read() {
                try store.adoptFollowUpSetting(setting, changed: LegacyFollowUpSetting.changeTime())
            }
            LegacyFollowUpSetting.remove()
        }
        opened = store
        return store
    }

    /// The one reminder engine of the process. Its runs do not overlap, so the app must not make a second one.
    /// Each successful run keeps the device time zone for the notification tap (spec 8.1, 8.3).
    func reminderEngine() throws(StorageError) -> ReminderEngine {
        if let engine { return engine }
        let engine = ReminderEngine(
            source: try open(),
            center: SystemReminderCenter(),
            ledger: DefaultsRemovalLedger(),
            privacy: DefaultsReminderPrivacy(),
            zoneRecord: DefaultsTimeZoneRecord(),
            alarms: coverNow
        )
        self.engine = engine
        return engine
    }

    /// The one follow-up engine of the process, with a removal ledger of its own (spec 4, 8.2).
    func followUpEngine() throws(StorageError) -> FollowUpEngine {
        if let followUps { return followUps }
        let followUps = FollowUpEngine(
            source: try open(),
            center: SystemReminderCenter(),
            ledger: DefaultsRemovalLedger(key: DefaultsRemovalLedger.followUpKey),
            privacy: DefaultsReminderPrivacy(),
            alarms: coverNow
        )
        self.followUps = followUps
        return followUps
    }

    /// The alarm engine of the process. It is `nil` before iOS 26, where AlarmKit does not exist (D079).
    func alarmEngine() throws(StorageError) -> AlarmEngine? {
        guard #available(iOS 26, *) else { return nil }
        if let alarms { return alarms }
        let alarms = AlarmEngine(
            source: try open(),
            center: SystemAlarmCenter(),
            privacy: DefaultsReminderPrivacy(),
            alarmsRing: { AlarmSupport.isAuthorized }
        )
        self.alarms = alarms
        return alarms
    }

    /// Runs the alarms, then the reminder engine, then the follow-ups. The alarm run comes first, so an alarm that the
    /// system did not schedule gives its item the normal reminder in the same run (D079). The reminder engine comes
    /// before the follow-ups: a run can remove follow-ups to make room under the system limit, and the refresh sets
    /// them again (spec 8.4).
    ///
    /// The run waits for the notification updates before it, so no two updates overlap.
    /// It returns the follow-up outcome too: `nil` when the follow-up refresh failed.
    func reconcileReminders(
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        mayAskForPermission: Bool = false
    ) async throws -> (reminders: ReminderOutcome, followUps: FollowUpOutcome?) {
        let previous = updates
        let run = Task { () throws -> (reminders: ReminderOutcome, followUps: FollowUpOutcome?) in
            await previous?.value
            // The cover is valid for this run only, and it fails open (D079). It starts empty. Only a run of the alarm
            // path with no error at all gives it items. An error of the read, a schedule, or a cancel keeps it empty,
            // so every item with an alarm gets its normal reminder.
            self.cover.withLock { $0 = .none }
            if let failed = try? await self.alarmEngine()?.refresh(at: now, deviceTimeZone: deviceTimeZone) {
                self.cover.withLock { $0 = AlarmCover(rings: AlarmSupport.isAuthorized, failed: failed) }
            }
            let outcome = try await self.reminderEngine().reconcile(
                at: now, deviceTimeZone: deviceTimeZone, mayAskForPermission: mayAskForPermission
            )
            let followUps = try? await self.followUpEngine().refresh(at: now, deviceTimeZone: deviceTimeZone)
            return (outcome, followUps)
        }
        updates = Task { _ = try? await run.value }
        return try await run.value
    }

    /// Replaces the data with a checked backup that the user confirmed (D040). The store removes the staged files.
    ///
    /// The change waits in the notification queue, so no run of an engine reads the database while it changes.
    /// The engines are made again after the change, so no engine keeps a state of the old data.
    /// After a failure the old data is in place. See `LocalStore.restore(_:)`.
    func restore(_ backup: StagedBackup) async throws(StorageError) -> RestoreResult {
        let previous = updates
        let run = Task { () -> Result<RestoreResult, StorageError> in
            await previous?.value
            return await self.replaceData(with: backup)
        }
        updates = Task { _ = await run.value }
        return try await run.value.get()
    }

    private func replaceData(with backup: StagedBackup) async -> Result<RestoreResult, StorageError> {
        let result: RestoreResult
        do throws(StorageError) {
            result = try await open().restore(backup)
        } catch {
            return .failure(error)
        }
        engine = nil
        followUps = nil
        alarms = nil
        // The restored items replace the old ones. The photo files of the old items have no owner now (D056).
        await removeUnreferencedPhotos()
        return .success(result)
    }

    /// Generates the occurrences around `now`, and builds the projection of the two tabs (spec 9).
    ///
    /// It reads the items, the slots, and the records of today's occurrences, and no older intake history (spec 7.3).
    /// With no `deviceTimeZone` it generates nothing, and the snapshot has no Today.
    /// `generation` is the generation of the data that the model read (D040).
    func snapshot(at now: Date, deviceTimeZone: NamedTimeZone?, generation: Int) async throws(StorageError) -> Snapshot {
        let store = try open()
        let interval = Signposts.signposter.beginInterval("ReadToday")
        var counts = (occurrences: 0, items: 0)
        defer {
            Signposts.signposter.endInterval(
                "ReadToday", interval, "\(counts.occurrences) occurrences, \(counts.items) items"
            )
        }
        let items = try await store.items()
        let remindersOff = try await store.itemIDsWithRemindersOff()
        counts.items = items.count
        var today: TodaySnapshot?
        if let deviceTimeZone {
            let loaded = try await TodaySnapshot.load(
                from: store, items: items, remindersOff: remindersOff,
                at: now, deviceTimeZone: deviceTimeZone, generation: generation
            )
            counts.occurrences = loaded.occurrences.count
            today = loaded.snapshot
            let date = LocalDate(now, in: deviceTimeZone)
            today?.asNeeded = AsNeededCard(try await store.asNeeded(on: date), items: items, on: date)
        }
        let entries = items.map {
            ListEntry(
                id: $0.id, name: $0.name, form: $0.form, color: $0.color,
                imageReference: $0.imageReference, remindersOff: remindersOff.contains($0.id)
            )
        }
        return Snapshot(
            today: today,
            list: zip(items, entries).filter { !$0.0.isArchived }.map(\.1),
            archived: zip(items, entries).filter { $0.0.isArchived }.map(\.1)
        )
    }

    /// The open store for a record transaction. An open failure becomes `RecordFailure.storage`.
    private func openForRecord() throws(RecordFailure) -> LocalStore {
        do throws(StorageError) {
            return try open()
        } catch {
            throw .storage(error)
        }
    }

    /// The record transaction for the events that the user chose on Today (spec 7.2).
    /// `generation` is the generation of the data that the model read (D040).
    func record(
        _ events: [(event: IntakeEvent, scheduleVersionID: ScheduleVersionID)],
        generation: Int,
        currentPlan: (@Sendable () -> OccurrenceGeneration?)? = nil,
        restoreEpoch: Int? = nil
    ) async throws(RecordFailure) -> [OccurrenceRecord] {
        let store = try openForRecord()
        let records = try await store.record(events, generation: generation, currentPlan: currentPlan, restoreEpoch: restoreEpoch)
        #if DEBUG
        // The "failed write" scenario: the commit is stored, and the caller gets `unavailable` (D014).
        if debug.failsNextRecord, DebugStore.directory != nil {
            debug.failsNextRecord = false
            throw .storage(.unavailable)
        }
        #endif
        return records
    }
}

extension AppStore {
    /// What the tap resolver reads: every item, also the archived ones, and every schedule with its full
    /// version history (spec 8.3).
    func tapInputs() async throws(StorageError) -> (items: [Item], schedules: [Schedule]) {
        let store = try open()
        let items = try await store.items()
        var schedules: [Schedule] = []
        for item in items {
            schedules += try await store.schedules(of: item.id)
        }
        return (items, schedules)
    }

    /// The stored occurrence and its record for each planned occurrence that the store has.
    /// A date that no generation run reached has no stored occurrence.
    func stored(
        _ planned: [PlannedOccurrence]
    ) async throws(StorageError) -> [OccurrenceKey: (occurrence: Occurrence, record: OccurrenceRecord)] {
        let store = try open()
        var occurrences: [Occurrence] = []
        for candidate in planned {
            if let occurrence = try await store.occurrence(slotID: candidate.slotID, on: candidate.plannedDate) {
                occurrences.append(occurrence)
            }
        }
        let records = try await store.records(of: occurrences.map(\.id))
        var result: [OccurrenceKey: (occurrence: Occurrence, record: OccurrenceRecord)] = [:]
        for occurrence in occurrences {
            result[occurrence.key] = (occurrence, records[occurrence.id] ?? OccurrenceRecord(occurrenceID: occurrence.id))
        }
        return result
    }
}

extension AppStore {
    /// The first event of a past dose that no generation run stored, with its occurrence, in one transaction.
    func recordBackfill(
        _ event: IntakeEvent, occurrence: Occurrence, generation: Int
    ) async throws(RecordFailure) -> OccurrenceRecord {
        let store = try openForRecord()
        return try await store.recordBackfill(event, occurrence: occurrence, generation: generation)
    }
}
