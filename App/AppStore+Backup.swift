import Foundation
import MaruCore
import MaruDatabase

/// The files of "Your Data" in settings: the record export, and the backup (D040).
extension AppStore {
    /// The folder of a file that waits for the share sheet. The file holds health data, so the folder
    /// has one file at most, and `removeExports` empties it when the share sheet closes and at launch (spec 10).
    private static let exportDirectory = URL.temporaryDirectory.appending(path: "Export", directoryHint: .isDirectory)

    /// Writes the record export, a CSV file, and returns it. `docs/export-format.md` has the format.
    func exportRecords(at now: Date, deviceTimeZone: NamedTimeZone) async throws -> URL {
        let doses = try await open().exportedDoses(through: LocalDate(now, in: deviceTimeZone), deviceTimeZone: deviceTimeZone)
        let file = try Self.newExportFile(named: "Maru Records \(Self.dayText(now)).csv")
        try Data(RecordExport.csv(doses).utf8).write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }

    /// The active items with their plans, for the medication list (D091). `owner` keeps the items of one member (D129).
    func medicationListData(owner: PersonID?) async throws -> [(item: Item, schedule: Schedule?)] {
        let store = try open()
        var rows: [(item: Item, schedule: Schedule?)] = []
        for item in try await store.items() where !item.isArchived && (owner == nil || item.personID == owner) {
            rows.append((item, try await store.schedules(of: item.id).first))
        }
        return rows
    }

    /// The counts of each item over the last `days` days, for the summary (D091). `owner` counts one member (T65).
    func summaryData(days: Int, at now: Date, deviceTimeZone: NamedTimeZone, owner: PersonID?) async throws -> HistorySummaryRead {
        try await open().summary(
            days: days, through: LocalDate(now, in: deviceTimeZone), at: now, deviceTimeZone: deviceTimeZone, owner: owner
        )
    }

    /// Writes a PDF report and returns the file. Like the other files it waits for the share sheet, and it holds health data.
    func writeReport(_ pdf: Data, named name: String, at now: Date) throws -> URL {
        let file = try Self.newExportFile(named: "\(name) \(Self.dayText(now)).pdf")
        try pdf.write(to: file, options: [.atomic, .completeFileProtection])
        return file
    }

    /// Writes a backup of the whole database with the settings of the app, and returns the file.
    func backUp(at now: Date, settings: [String: String]) async throws -> URL {
        let store = try open()
        let file = try Self.newExportFile(named: "Maru Backup \(Self.dayText(now)).\(BackupFormat.fileExtension)")
        try await store.backUp(to: file, settings: settings)
        return file
    }

    nonisolated func removeExports() {
        try? FileManager.default.removeItem(at: Self.exportDirectory)
    }

    /// Checks a backup file that the user picked. The database does not change (T38).
    /// The file can be outside the app, for example in iCloud Drive, so the read is coordinated.
    func stage(backup file: URL) throws(StorageError) -> StagedBackup {
        let store = try open()
        var result: Result<StagedBackup, StorageError> = .failure(.unavailable)
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &coordinationError) { url in
            do throws(StorageError) {
                result = .success(try store.stage(backup: url))
            } catch {
                result = .failure(error)
            }
        }
        switch result {
        case let .success(staged): return staged
        case let .failure(error): throw error
        }
    }

    /// Removes a checked backup that the user did not confirm.
    func discard(_ backup: StagedBackup) {
        try? open().discard(backup)
    }

    /// An empty export folder with the strict file protection, and the place of a new file in it.
    private static func newExportFile(named name: String) throws -> URL {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: exportDirectory)
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        // A file gets the level of its folder. The two writers also set the level on the file.
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: exportDirectory.path)
        return exportDirectory.appending(path: name)
    }

    /// `YYYY-MM-DD` in the time zone of the device, for a file name.
    private static func dayText(_ now: Date) -> String {
        now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }
}
