import Foundation
import GRDB
import MaruCore
import os

/// A stored row broke a rule of the app and did not load (D088). The error carries the rule as a fixed word and nothing
/// else, so it is safe to log (spec 10). `StorageError` maps it to `invalidData`.
struct DecodeRule: Error, Sendable {
    let rule: StoredDataRule
}

/// A read for the reminder plans failed with `invalidData`. It carries the rule of the row that did not load (D088).
/// It holds a fixed word and nothing else, so it is safe to log and to send as a statistic (spec 10).
public struct PlanReadError: Error, Sendable {
    public let storage: StorageError
    public let rule: StoredDataRule
}

/// What the process knows about rows that did not load. The log names the rule, and never a name, a dose, a time, or an ID.
enum DecodeFaults {
    private struct State {
        var logged: Set<StoredDataRule> = []
        var skipped: [StoredDataRule] = []
        var reported: Set<StoredDataRule> = []
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Maru", category: "reminders")

    /// A row did not load, and the reminder plan skipped it. The log has one line for each rule in each process.
    static func skipped(_ rule: StoredDataRule) {
        let first = state.withLock { state -> Bool in
            if !state.skipped.contains(rule) { state.skipped.append(rule) }
            return state.logged.insert(rule).inserted
        }
        if first { log.error("A stored row did not load and the reminder run skipped it. Rule: \(rule.rawValue, privacy: .public)") }
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
}

extension LocalStore {
    /// The rules of the rows that the reminder plans skipped, each one time in a process (D088). The app reports them.
    public static func takeSkippedRules() -> [StoredDataRule] { DecodeFaults.takeSkipped() }

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

    /// Every item and every schedule. A row that does not load is `invalidData`. Today, History, My Items, the widget, and every
    /// write use this, so a damaged row shows the storage problem and never hides data (spec 7.3).
    /// `owner` reads only the items of one member and their schedules, `nil` every item (T65).
    static func itemsAndSchedules(_ db: Database, owner: PersonID? = nil) throws -> (items: [Item], schedules: [Schedule]) {
        let items = try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid").map(decodeItem)
            .filter { owner == nil || $0.personID == owner }
        let itemIDs = Set(items.map(\.id))
        let schedules = try String.fetchAll(db, sql: "SELECT id FROM schedule ORDER BY rowid")
            .compactMap { try fetchSchedule(db, id: ScheduleID(text: $0)) }
            .filter { owner == nil || itemIDs.contains($0.itemID) }
        return (items, schedules)
    }

    /// The inputs of the reminder plans (D088). An item or a schedule that does not load is skipped and logged, so one bad row
    /// does not stop the reminders of the other items. The schedules that were skipped, and the schedules of a skipped item,
    /// are in `unreadable`. The plan reports each as not set, and the engines remove nothing while there is one.
    /// `family` has the members, so the text can name the owner of a dose (D123).
    static func planInputs(
        _ db: Database
    ) throws -> (items: [Item], schedules: [Schedule], unreadable: Set<ScheduleID>, family: Family) {
        // A member that does not load is skipped. Its items must not produce an ambiguous reminder (D123).
        var people: [Person] = []
        for row in try Row.fetchAll(db, sql: "SELECT * FROM person ORDER BY rowid") {
            do {
                people.append(try decodePerson(row))
            } catch let error as DecodeRule {
                DecodeFaults.skipped(error.rule)
            }
        }
        var items: [Item] = []
        for row in try Row.fetchAll(db, sql: "SELECT * FROM item ORDER BY rowid") {
            do {
                let item = try decodeItem(row)
                guard let person = people.first(where: { $0.id == item.personID }), item.isArchived || !person.isArchived else {
                    throw DecodeRule(rule: .itemPerson)
                }
                items.append(item)
            } catch let error as DecodeRule {
                DecodeFaults.skipped(error.rule)
            }
        }
        let known = Set(items.map(\.id))
        var schedules: [Schedule] = []
        var unreadable: Set<ScheduleID> = []
        for row in try Row.fetchAll(db, sql: "SELECT id, itemID FROM schedule ORDER BY rowid") {
            let id = try? ScheduleID(text: row["id"] as String)
            do {
                guard let id else { throw DecodeRule(rule: .scheduleRow) }
                let itemID = try named(.scheduleRow) { try ItemID(text: row["itemID"] as String) }
                guard known.contains(itemID) else { throw DecodeRule(rule: .itemRow) }
                if let schedule = try fetchSchedule(db, id: id) { schedules.append(schedule) }
            } catch let error as DecodeRule {
                DecodeFaults.skipped(error.rule)
                if let id { unreadable.insert(id) }
            }
        }
        return (items, schedules, unreadable, Family(people: people))
    }

    /// The schedule of the slot that a raw occurrence row names, or `nil` when the row or the slot does not say it.
    /// A row that does not decode marks this schedule as unreadable, so the engines remove nothing for it (D089).
    static func scheduleID(ofOccurrenceRow row: Row, _ db: Database) throws -> ScheduleID? {
        guard let slot = row["slotID"] as String?,
              let text = try String.fetchOne(db, sql: "SELECT scheduleID FROM scheduleSlot WHERE id = ?", arguments: [slot])
        else { return nil }
        return try? ScheduleID(text: text)
    }

    /// Reads for a reminder plan. A decode failure carries its rule (D088).
    func readPlan<T: Sendable>(_ value: @Sendable (Database) throws -> T) async throws -> T {
        do {
            return try await writer.read(value)
        } catch {
            let storage = StorageError(error)
            if let rule = (error as? DecodeRule)?.rule { throw PlanReadError(storage: storage, rule: rule) }
            throw storage
        }
    }
}
