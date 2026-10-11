/// A dose that the user typed. It is free text and keeps the exact original form, including units.
///
/// There is no default dose, no parsing, and no unit conversion (spec 2.1, 7.2).
/// "500 mg", "500 μg", "10000 IU", and "1 capsule" are different values. IU needs no special case.
public struct Dose: Hashable, Sendable {
    public let text: String

    /// Returns `nil` when the text is blank, because a blank dose means "no dose".
    /// The text is stored exactly as given.
    public init?(_ text: String) {
        guard !text.allSatisfy(\.isWhitespace) else { return nil }
        self.text = text
    }
}
