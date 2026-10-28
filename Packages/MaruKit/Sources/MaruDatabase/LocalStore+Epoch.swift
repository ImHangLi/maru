import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// The file with the restore epoch, next to the database (D048).
    static let epochFileName = "restore-epoch"

    /// The restore epoch of the data in `directory`: a number that a restore changes twice, at its start and at its end.
    /// A missing file is 0. An odd number means that a restore runs or stopped in the middle.
    /// It survives a relaunch, so a widget that read the data before a restore can never record after it (D040, D048).
    /// `nil` when the file is not readable, for example after a restart of the iPhone and before the first unlock. It holds no health data.
    public static func restoreEpoch(in directory: URL) -> Int? {
        let file = directory.appendingPathComponent(epochFileName)
        guard FileManager.default.fileExists(atPath: file.path) else { return 0 }
        guard let data = try? Data(contentsOf: file), let value = Int(String(decoding: data, as: UTF8.self)) else { return nil }
        return value
    }

    /// Adds one to the epoch. The restore calls it from inside the write barrier of the store.
    func bumpEpoch() throws {
        guard let current = Self.restoreEpoch(in: directory) else { throw StorageError.unavailable }
        let file = directory.appendingPathComponent(Self.epochFileName)
        try Data(String(current + 1).utf8).write(to: file, options: .atomic)
        try FileProtection.protect(files: [file])
    }

    /// Makes an odd epoch even. A restore that the system stopped between its two changes leaves the epoch odd, and every widget
    /// action refuses an odd epoch. The change of the number also refuses an action that read the data before the stop (D048, D089).
    /// It is best effort: when the file cannot be written, the widget stays off until the next start.
    static func closeInterruptedRestoreEpoch(in directory: URL) {
        guard let current = restoreEpoch(in: directory), current % 2 == 1 else { return }
        let file = directory.appendingPathComponent(epochFileName)
        guard (try? Data(String(current + 1).utf8).write(to: file, options: .atomic)) != nil else { return }
        try? FileProtection.protect(files: [file])
    }

    /// The restore epoch of this store. See `restoreEpoch(in:)`.
    public var restoreEpoch: Int? { Self.restoreEpoch(in: directory) }

    /// Waits again until the storage medium has the commits of this store. The widget uses it when a record
    /// committed and the first flush failed (D048). It is the flush that every record makes.
    public func flushCommits() -> Bool {
        Self.flush(walFile)
    }
}

/// What the widgets read in one read transaction (D048).
public struct WidgetRead: Sendable {
    public let epoch: Int
    public let items: [Item]
    /// The occurrences of the plan of now, also those that no generation run stored. A stored one keeps its ID.
    public let occurrences: [Occurrence]
    public let planZones: Set<NamedTimeZone>
    public let itemIDsBySlot: [ScheduleSlotID: ItemID]
    public let doses: [ScheduleVersionID: Dose]
    public let records: [OccurrenceID: OccurrenceRecord]
}

extension LocalStore {
    /// Reads today for a widget (D048). It changes nothing: it opens the database read-only, so it creates no file,
    /// runs no migration, removes no staged backup, and stores no occurrence. A database that is not there throws
    /// `unavailable`. The new occurrences are planned in memory only. A tap on one of them finds no stored
    /// occurrence, and the app opens.
    ///
    /// One read transaction gives one state. The restore epoch is read before and after it. A restore that
    /// runs, or ran in between, throws `unavailable`, so the widget never draws a mix of old and restored data.
    public static func readForWidget(
        in directory: URL, at now: Date, deviceTimeZone: NamedTimeZone
    ) throws(StorageError) -> WidgetRead {
        try readOnly(in: directory) { db, epoch -> WidgetRead in
            let (items, schedules) = try Self.itemsAndSchedules(db)
            let generation = OccurrenceGeneration(now: now, deviceTimeZone: deviceTimeZone)
            let dates = generation.candidateDates
            let stored = try Row.fetchAll(
                db,
                sql: """
                    SELECT occurrence.*,
                        EXISTS (SELECT 1 FROM occurrenceState WHERE occurrenceID = occurrence.id) AS isRecorded
                    FROM scheduleSlot CROSS JOIN occurrence
                        ON occurrence.slotID = scheduleSlot.id AND occurrence.plannedDate BETWEEN ? AND ?
                    ORDER BY occurrence.rowid
                    """,
                arguments: [try dates[0].text, try dates[dates.count - 1].text]
            ).map { row in
                StoredOccurrence(occurrence: try decodeOccurrence(row), isRecorded: try row.decode(forColumn: "isRecorded"))
            }
            let outcome = generation.outcome(items: items, schedules: schedules, stored: stored)
            let storedIDs = Set(stored.map(\.occurrence.id))
            var records: [OccurrenceID: OccurrenceRecord] = [:]
            for occurrence in outcome.occurrences where storedIDs.contains(occurrence.id) {
                records[occurrence.id] = try fetchCheckedRecord(db, occurrenceID: occurrence.id)
            }
            var itemIDs: [ScheduleSlotID: ItemID] = [:]
            for row in try Row.fetchAll(
                db,
                sql: "SELECT scheduleSlot.id, schedule.itemID FROM scheduleSlot JOIN schedule ON schedule.id = scheduleSlot.scheduleID"
            ) {
                itemIDs[try ScheduleSlotID(text: row.decode(forColumn: "id"))] = try ItemID(text: row.decode(forColumn: "itemID"))
            }
            var doses: [ScheduleVersionID: Dose] = [:]
            for id in Set(outcome.occurrences.map(\.scheduleVersionID)) {
                if let text = try String.fetchOne(db, sql: "SELECT dose FROM scheduleVersion WHERE id = ?", arguments: [id.text]) {
                    guard let dose = Dose(text) else { throw StorageError.invalidData }
                    doses[id] = dose
                }
            }
            let planZones = schedules.flatMap(\.versions).map { version in
                switch version.timeZonePolicy {
                case .fixed(let zone): zone
                case .followsDevice: deviceTimeZone
                }
            }
            return WidgetRead(
                epoch: epoch, items: items, occurrences: outcome.occurrences, planZones: Set(planZones),
                itemIDsBySlot: itemIDs, doses: doses, records: records
            )
        }
    }

    /// One read transaction of a widget (D048, D108). It opens the database read-only, so it creates no file, runs no
    /// migration, removes no staged backup, and stores nothing. A database that is not there throws `unavailable`.
    /// The restore epoch is read before and after the read. A restore that runs, or ran in between, throws `unavailable`.
    /// `body` gets the restore epoch of the data.
    static func readOnly<T>(in directory: URL, _ body: (Database, Int) throws -> T) throws(StorageError) -> T {
        do {
            guard let epoch = restoreEpoch(in: directory), epoch % 2 == 0, try hasDatabase(in: directory) else {
                throw StorageError.unavailable
            }
            var configuration = Configuration()
            configuration.readonly = true
            configuration.foreignKeysEnabled = true
            configuration.busyMode = .timeout(3)
            let queue = try DatabaseQueue(
                path: directory.appendingPathComponent(fileName).path, configuration: configuration
            )
            defer { try? queue.close() }
            let result = try queue.read { db in try body(db, epoch) }
            guard restoreEpoch(in: directory) == epoch else { throw StorageError.unavailable }
            return result
        } catch {
            throw StorageError(error)
        }
    }
}
