/// The usual form and the common amounts, times, and note of one supplement, from the built-in list (D043).
///
/// It is smart completion, not medical advice. The edit screen shows the amounts, the times, and the note as
/// candidates, and nothing fills until the user taps one. Only the form changes by itself, and only while the
/// user did not choose a form on the screen. A medication gets no completion (spec 2.1).
public struct SmartCompletion: Equatable, Sendable {
    public var form: ItemForm?
    public var amounts: [String]
    public var times: [DayPart]
    public var notes: [IntakeNote]

    public init(form: ItemForm? = nil, amounts: [String] = [], times: [DayPart] = [], notes: [IntakeNote] = []) {
        self.form = form
        self.amounts = amounts
        self.times = times
        self.notes = notes
    }

    /// No amount, time, or note to propose.
    public var hasNoCandidates: Bool { amounts.isEmpty && times.isEmpty && notes.isEmpty }

    /// The candidates that the draft does not have yet.
    ///
    /// The amounts show while the field is blank or holds one of them, so a tap can change it to another.
    /// An amount that the user typed hides them. A time shows while the draft has no time in its part of
    /// the day. A note shows while the draft has no note.
    public func open(amount: String, times draftTimes: [WallClockTime], hasNote: Bool) -> SmartCompletion {
        let typed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOwnAmount = !typed.isEmpty && !amounts.contains { $0.caseInsensitiveCompare(typed) == .orderedSame }
        let parts = Set(draftTimes.map(DayPart.init))
        return SmartCompletion(
            form: form,
            amounts: isOwnAmount ? [] : amounts.filter { $0.caseInsensitiveCompare(typed) != .orderedSame },
            times: times.filter { !parts.contains($0) },
            notes: hasNote ? [] : notes
        )
    }

    /// What the form row does.
    public enum FormStep: Equatable, Sendable {
        case none
        /// Set the form, because the user did not choose one on this screen.
        case set(ItemForm)
        /// Offer the form with one tap. The form of the user stays.
        case propose(ItemForm)
    }

    /// The form from the label scan comes before the usual form, because it is the form of this product (D038).
    /// `mayChange` is false after the user chose a form on the screen, and for a medication.
    public static func formStep(usual: ItemForm?, scanned: ItemForm?, current: ItemForm, mayChange: Bool) -> FormStep {
        guard let form = scanned ?? usual, form != current else { return .none }
        return mayChange ? .set(form) : .propose(form)
    }

    /// Reads one line of the list: name, form, amounts, times, note, and source, separated by "|".
    /// A word that the list does not know gives no candidate.
    init(fields: [String]) {
        func field(_ index: Int) -> String { index < fields.count ? fields[index] : "" }
        func values(_ index: Int) -> [String] {
            field(index).split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        form = switch field(1).lowercased() {
        case "capsule": .capsule
        case "tablet": .tablet
        case "softgel": .softgel
        case "powder": .powder
        case "drop": .drop
        default: nil
        }
        amounts = Array(values(2).prefix(3))
        times = values(3).compactMap { word in
            switch word.lowercased() {
            case "morning": .morning
            case "noon": .noon
            case "evening": .evening
            default: nil
            }
        }
        let note = field(4)
        notes = switch note.lowercased() {
        case "": []
        case "with food": [.preset(.withFood)]
        case "empty stomach": [.preset(.emptyStomach)]
        default: [.text(note)]
        }
    }
}

extension DayPart {
    /// The time that a tap on this part adds (spec 2.1): the earliest time in this part that the user already
    /// confirmed for a supplement, else the example time of the part: 08:00, 12:00, or 20:00.
    public func time(confirmed: [WallClockTime]) -> WallClockTime {
        if let time = confirmed.filter({ DayPart($0) == self }).min() { return time }
        return switch self {
        case .morning: try! WallClockTime(hour: 8, minute: 0)
        case .noon: try! WallClockTime(hour: 12, minute: 0)
        case .evening: try! WallClockTime(hour: 20, minute: 0)
        }
    }
}
