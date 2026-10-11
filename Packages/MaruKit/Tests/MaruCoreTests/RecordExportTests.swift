import Foundation
import Testing
@testable import MaruCore

struct RecordExportTests {
    /// D040: a name or an amount with a comma, a quotation mark, or a line break stays one field.
    @Test func aDifficultNameStaysOneField() throws {
        let zone = try NamedTimeZone(identifier: "Asia/Shanghai")
        let taken = ExportedDose(
            date: try LocalDate(year: 2026, month: 3, day: 1),
            plannedTime: try WallClockTime(hour: 8, minute: 0),
            itemName: "Zinc, 15 mg \"chelated\"\nwith copper",
            category: .supplement,
            dose: Dose("1, or 2"),
            status: .taken,
            takenAt: try Date("2026-03-01T00:05:00Z", strategy: .iso8601),
            timeZone: zone
        )
        let asNeeded = ExportedDose(
            date: try LocalDate(year: 2026, month: 3, day: 1),
            plannedTime: nil,
            itemName: "维生素 D",
            category: .unknown,
            dose: nil,
            status: .skipped,
            takenAt: nil,
            timeZone: zone
        )

        let csv = RecordExport.csv([taken, asNeeded])

        #expect(csv == "\u{FEFF}"
            + "Date,Planned Time,Item,Type,Amount,State,Time Taken,Time Zone\r\n"
            + "2026-03-01,08:00,\"Zinc, 15 mg \"\"chelated\"\"\nwith copper\",Supplement,\"1, or 2\",Taken,2026-03-01 08:05,Asia/Shanghai\r\n"
            + "2026-03-01,,维生素 D,,,Skipped,,Asia/Shanghai\r\n")
    }
}
