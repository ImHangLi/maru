import Foundation

/// One line of the record export: one dose and the state that is valid now (D040).
public struct ExportedDose: Hashable, Sendable {
    /// The plan date of a scheduled dose, or the date of the record of an as-needed dose.
    public let date: LocalDate
    /// `nil` for an as-needed dose, which has no plan.
    public let plannedTime: WallClockTime?
    public let itemName: String
    public let category: ItemCategory
    /// The amount as the user wrote it. The export does not parse or convert it (spec 7.2).
    public let dose: Dose?
    public let status: OccurrenceStatus
    /// When the user says the intake happened. `nil` for a dose that is not taken.
    public let takenAt: Date?
    /// The zone of the date and of the two times.
    public let timeZone: NamedTimeZone
    /// The member of the Family that owns the item now: the name, or "Me" for "Me" before a rename (D121, D129).
    public let person: String

    public init(
        date: LocalDate,
        plannedTime: WallClockTime?,
        itemName: String,
        category: ItemCategory,
        dose: Dose?,
        status: OccurrenceStatus,
        takenAt: Date?,
        timeZone: NamedTimeZone,
        person: String
    ) {
        self.date = date
        self.plannedTime = plannedTime
        self.itemName = itemName
        self.category = category
        self.dose = dose
        self.status = status
        self.takenAt = takenAt
        self.timeZone = timeZone
        self.person = person
    }
}

/// The record export as CSV text (D040). `docs/export-format.md` describes the format. Keep the two the same.
///
/// The words of the file are fixed English text and not product copy, so a file reads the same on every device.
public enum RecordExport {
    /// "Person" is last and always there, also with one member, so a parser of an older file reads the same columns (D129).
    static let header = ["Date", "Planned Time", "Item", "Type", "Amount", "State", "Time Taken", "Time Zone", "Person"]

    /// The value of "Person" for "Me" before a rename. Fixed English, as the other words of the file.
    public static let meName = "Me"

    /// The text of the file: a header line, then one line for each dose, in the given order.
    ///
    /// The text starts with a byte order mark, so Excel reads it as UTF-8. Each line ends with CR LF (RFC 4180).
    public static func csv(_ doses: [ExportedDose]) -> String {
        let lines = [header] + doses.map { dose in
            [
                dose.date.dayText,
                dose.plannedTime.map(clockText) ?? "",
                dose.itemName,
                typeText(dose.category),
                dose.dose?.text ?? "",
                stateText(dose.status),
                dose.takenAt.map { instant in
                    "\(LocalDate(instant, in: dose.timeZone).dayText) \(clockText(WallClockTime(instant, in: dose.timeZone)))"
                } ?? "",
                dose.timeZone.identifier,
                dose.person,
            ]
        }
        return "\u{FEFF}" + lines.map { $0.map(field).joined(separator: ",") + "\r\n" }.joined()
    }

    /// A field that starts with `=`, `+`, `-`, `@`, a tab, or a carriage return gets an apostrophe in front,
    /// so a spreadsheet app shows it as text and does not run it as a formula (OWASP). The stored text does not change.
    ///
    /// A field with a comma, a quotation mark, or a line break goes in quotation marks, and each quotation
    /// mark in it is written two times (RFC 4180).
    private static func field(_ text: String) -> String {
        var text = text
        if let first = text.unicodeScalars.first, ["=", "+", "-", "@", "\t", "\r"].contains(first) {
            text = "'" + text
        }
        guard text.unicodeScalars.contains(where: { [",", "\"", "\r", "\n"].contains($0) }) else { return text }
        return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// `HH:MM`.
    private static func clockText(_ time: WallClockTime) -> String {
        String(format: "%02d:%02d", time.hour, time.minute)
    }

    private static func typeText(_ category: ItemCategory) -> String {
        switch category {
        case .supplement: "Supplement"
        case .medication: "Medication"
        case .unknown: ""
        }
    }

    private static func stateText(_ status: OccurrenceStatus) -> String {
        switch status {
        case .taken: "Taken"
        case .skipped: "Skipped"
        case .unrecorded: "No record"
        }
    }
}
