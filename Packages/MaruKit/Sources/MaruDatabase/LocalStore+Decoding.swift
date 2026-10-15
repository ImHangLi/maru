import Foundation
import GRDB
import MaruCore
import os

/// A stored row broke a rule of the app and did not load (D088). The error carries the rule as a fixed word and nothing
/// else, so it is safe to log (spec 10). `StorageError` maps it to `invalidData`.
struct DecodeRule: Error, Sendable {
    let rule: StoredDataRule
}

/// What the process knows about rows that did not load. The log names the rule, and never a name, a dose, a time, or an ID.
enum DecodeFaults {
    private struct State {
        var logged: Set<StoredDataRule> = []
        var skipped: [StoredDataRule] = []
        var reported: Set<StoredDataRule> = []
        var thrown: StoredDataRule?
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Maru", category: "reminders")

    /// A row did not load, and the read skipped it. The log has one line for each rule in each process.
    static func skipped(_ rule: StoredDataRule) {
        let first = state.withLock { state -> Bool in
            if !state.skipped.contains(rule) { state.skipped.append(rule) }
            return state.logged.insert(rule).inserted
        }
        if first { log.error("A stored row did not load and was skipped. Rule: \(rule.rawValue, privacy: .public)") }
    }

    /// A read or a write failed with `invalidData`, and this rule was broken.
    static func thrown(_ rule: StoredDataRule) {
        state.withLock { $0.thrown = rule }
        log.error("A stored row did not load. Rule: \(rule.rawValue, privacy: .public)")
    }

    /// The rules that no call returned before, so a bad row gives one report in a process and not one for each read.
    static func takeSkipped() -> [StoredDataRule] {
        state.withLock { state in
            let fresh = state.skipped.filter { !state.reported.contains($0) }
            state.reported.formUnion(fresh)
            state.skipped = []
            return fresh
        }
    }

    static var lastThrown: StoredDataRule? { state.withLock { $0.thrown } }
}

extension LocalStore {
    /// The rules of the rows that reads skipped, each one time in a process (D088). The app reports them.
    public static func takeSkippedRules() -> [StoredDataRule] { DecodeFaults.takeSkipped() }

    /// The rule that the last `invalidData` of this process broke, for the log line of a failed run (D088).
    public static var lastInvalidDataRule: StoredDataRule? { DecodeFaults.lastThrown }

    /// Runs `body`. A decode failure inside it becomes a `DecodeRule`. A rule of the schedule or the item that the
    /// domain rejected gives its own rule, and the others give `rule`. An error of the database goes through.
    static func named<T>(_ rule: StoredDataRule, _ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as DecodeRule {
            throw error
        } catch let error as StorageError {
            guard error == .invalidData else { throw error }
            throw DecodeRule(rule: rule)
        } catch is RowDecodingError {
            throw DecodeRule(rule: rule)
        } catch let error as DatabaseError {
            throw error
        } catch {
            let specific = StoredDataRule(domainError: error)
            throw DecodeRule(rule: specific == .other ? rule : specific)
        }
    }

    /// The items and the schedules that load. A row that does not load is skipped and logged, so one bad row does not stop
    /// Today, the history, or the reminders of the other items (D088). A schedule of a skipped item is skipped too.
    static func itemsAndSchedules(_ db: Database) throws -> (items: [Item], schedules: [Schedule]) {
        let items = try decodeItemsSkippingFaults(Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid"))
        let known = Set(items.map(\.id))
        var schedules: [Schedule] = []
        for id in try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid") {
            do {
                guard let schedule = try named(.scheduleRow, { try fetchSchedule(db, id: ScheduleID(text: id)) }) else { continue }
                if known.contains(schedule.itemID) { schedules.append(schedule) }
            } catch let error as DecodeRule {
                DecodeFaults.skipped(error.rule)
            }
        }
        return (items, schedules)
    }

    static func decodeItemsSkippingFaults(_ rows: [Row]) throws -> [Item] {
        var items: [Item] = []
        for row in rows {
            do {
                items.append(try decodeItem(row))
            } catch let error as DecodeRule {
                DecodeFaults.skipped(error.rule)
            }
        }
        return items
    }
}
