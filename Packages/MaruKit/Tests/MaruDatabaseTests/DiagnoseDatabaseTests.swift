import Foundation
import GRDB
import MaruCore
import Testing
@testable import MaruDatabase

/// A tool, not a check (D088). It finds the row that does not load in a copy of a database from a device.
///
///     MARU_DIAGNOSE_DB=/path/to/maru.sqlite swift test --package-path Packages/MaruKit --filter DiagnoseDatabaseTests
///
/// It opens a copy, so the file stays as it is. It prints the broken rule of each item and each schedule, and for a schedule
/// the position and the start date of each version. It prints no name, no dose, and no note.
@Suite struct DiagnoseDatabaseTests {
    static let path = ProcessInfo.processInfo.environment["MARU_DIAGNOSE_DB"]

    @Test(.enabled(if: path != nil)) func printTheBrokenRows() async throws {
        let directory = TestDirectory()
        try FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: Self.path!), to: directory.databaseFile)
        for suffix in ["-wal", "-shm"] where FileManager.default.fileExists(atPath: Self.path! + suffix) {
            try FileManager.default.copyItem(
                at: URL(fileURLWithPath: Self.path! + suffix), to: URL(fileURLWithPath: directory.databaseFile.path + suffix)
            )
        }
        let store = try LocalStore(directory: directory.url)
        let report = try await store.writer.read { db -> [String] in
            var lines: [String] = []
            for (index, row) in try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").enumerated() {
                do { _ = try LocalStore.decodeItem(row) } catch let error as DecodeRule {
                    lines.append("item #\(index): \(error.rule.rawValue)")
                }
            }
            for (index, id) in try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid").enumerated() {
                do { _ = try LocalStore.fetchSchedule(db, id: ScheduleID(text: id)) } catch let error as DecodeRule {
                    lines.append("schedule #\(index): \(error.rule.rawValue)")
                    for version in try Row.fetchAll(
                        db, sql: "SELECT position, effectiveFrom, timeZonePolicy, cycleStart IS NOT NULL AS cycle FROM scheduleVersion WHERE scheduleID = ? ORDER BY position",
                        arguments: [id]
                    ) {
                        lines.append("  version \(version["position"] as Int): from \(version["effectiveFrom"] as String), \(version["timeZonePolicy"] as String), cycle \(version["cycle"] as Bool)")
                    }
                }
            }
            return lines
        }
        print("DIAGNOSE: " + (report.isEmpty ? "every row loads" : "\n" + report.joined(separator: "\n")))
    }
}
