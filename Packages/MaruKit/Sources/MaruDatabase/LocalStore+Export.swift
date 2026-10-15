import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// How many days one read of the history covers in the record export.
    private static let exportPageDays = 90

    /// Every dose that the history shows, and every recorded dose of `today` or a later date, the oldest first (D040).
    ///
    /// The rules of `History` decide the lines: a dose with a record, and a planned dose with no record.
    /// A dose of today or a later date with no record is not a line, because the day did not end. An as-needed
    /// dose that the user took back is not a line, because it has no plan. A dose in a fixed time zone, or a dose
    /// of a stay in another zone, can have a date after the device date. Its record is a line too.
    ///
    /// One read gives every line, so a record that commits during the export is in all of the file or in none of it.
    public func exportedDoses(through today: LocalDate, deviceTimeZone: NamedTimeZone) async throws(StorageError) -> [ExportedDose] {
        try await read { db in
            var amounts: [ScheduleVersionID: Dose] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT id, dose FROM scheduleVersion WHERE dose IS NOT NULL") {
                // `Dose` rejects blank text, so a stored dose is never blank.
                guard let dose = Dose(try row.decode(forColumn: "dose")) else { throw StorageError.invalidData }
                amounts[try ScheduleVersionID(text: row.decode(forColumn: "id"))] = dose
            }
            let lastRecord = try String.fetchOne(
                db,
                sql: """
                    SELECT MAX(occurrence.plannedDate)
                    FROM occurrence
                    WHERE EXISTS (SELECT 1 FROM intakeEvent WHERE occurrenceID = occurrence.id)
                    """
            ).map(LocalDate.init(text:))
            // The newest day first, as the history reads.
            var days: [[ExportedDose]] = []
            var before = max(today, lastRecord ?? today).adding(days: 1)
            while true {
                let page = try Self.historyPage(db, before: before, days: Self.exportPageDays, deviceTimeZone: deviceTimeZone)
                let items = Dictionary(page.items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                for day in page.days {
                    var lines: [ExportedDose] = []
                    for dose in day.doses where day.date < today || dose.record.status != .unrecorded {
                        guard let item = items[dose.itemID] else { throw StorageError.invalidData }
                        lines.append(
                            ExportedDose(
                                date: day.date,
                                plannedTime: dose.occurrence.plannedTime,
                                itemName: item.name,
                                category: item.category,
                                dose: amounts[dose.occurrence.scheduleVersionID],
                                status: dose.record.status,
                                takenAt: Self.takenAt(dose.record),
                                timeZone: dose.occurrence.timeZone
                            )
                        )
                    }
                    for dose in day.asNeeded where dose.record.status != .unrecorded {
                        guard let item = items[dose.occurrence.itemID] else { throw StorageError.invalidData }
                        lines.append(
                            ExportedDose(
                                date: day.date,
                                plannedTime: nil,
                                itemName: item.name,
                                category: item.category,
                                dose: dose.occurrence.dose,
                                status: dose.record.status,
                                takenAt: Self.takenAt(dose.record),
                                timeZone: dose.occurrence.timeZone
                            )
                        )
                    }
                    days.append(lines)
                }
                guard page.hasEarlier else { break }
                before = before.adding(days: -Self.exportPageDays)
            }
            return days.reversed().flatMap(\.self)
        }
    }

    private static func takenAt(_ record: OccurrenceRecord) -> Date? {
        record.currentEvent.flatMap { $0.action == .taken ? $0.occurredAt : nil }
    }
}
