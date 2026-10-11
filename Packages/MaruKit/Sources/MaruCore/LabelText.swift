import Foundation

/// A form word that a label can show. Maru has no gummy form, so that word gives no proposal.
public enum LabelForm: Hashable, Sendable {
    case softgel
    case capsule
    case tablet
    case powder
    case drop
    case gummy
}

/// The rules for text that the user tapped in the label scan (D038).
///
/// The scan only proposes. The user sees each value on the edit screen before the save.
public enum LabelText {
    /// The text of a label in a form that reads well as a name.
    ///
    /// It removes trademark signs and footnote marks, it makes a space from a dot between two parts, and
    /// it makes one space from each run of spaces and line breaks. A text in capitals only becomes readable: "VITAMIN D3" becomes "Vitamin D3".
    /// A text with a lowercase letter keeps its letters, because the label then shows the intended form.
    public static func clean(_ text: String) -> String {
        // A removed sign must not join two parts: "D3·K2" is "D3 K2", and "NOW®Foods" is "NOW Foods".
        var plain = String.UnicodeScalarView()
        var joins = false
        for scalar in text.unicodeScalars {
            if scalar.properties.isWhitespace || dots.contains(scalar) {
                plain.append(" ")
            } else if marks.contains(scalar) {
                joins = true
                continue
            } else {
                let isWordPart = scalar.properties.isAlphabetic || scalar.properties.numericType != nil
                if joins, isWordPart, let last = plain.last, last != " " { plain.append(" ") }
                plain.append(scalar)
            }
            joins = false
        }
        var words = String(plain).split(separator: " ").map(String.init)
        let letters = words.joined().filter(\.isLetter)
        if !letters.isEmpty, !letters.contains(where: \.isLowercase) {
            words = words.enumerated().map { readable($0.element, isFirst: $0.offset == 0) }
        }
        return words.joined(separator: " ")
    }

    /// The name from the texts that the user tapped, in the order of the taps.
    public static func name(from parts: [String]) -> String {
        clean(parts.joined(separator: " "))
    }

    /// The form words in a text of the label.
    public static func forms(in text: String) -> Set<LabelForm> {
        let lowered = text.lowercased()
            .replacingOccurrences(of: "soft gel", with: "softgel")
            .replacingOccurrences(of: "soft-gel", with: "softgel")
        var found: Set<LabelForm> = []
        for word in lowered.split(whereSeparator: { !$0.isLetter }) {
            if let form = formWords[String(word)] { found.insert(form) }
        }
        return found
    }

    /// The form to propose: only when the label shows exactly one form, and Maru has that form.
    /// "Softgel capsules" is one form, a softgel.
    public static func proposedForm(from seen: Set<LabelForm>) -> ItemForm? {
        var seen = seen
        if seen.contains(.softgel) { seen.remove(.capsule) }
        guard seen.count == 1 else { return nil }
        return switch seen.first {
        case .softgel: .softgel
        case .capsule: .capsule
        case .tablet: .tablet
        case .powder: .powder
        case .drop: .drop
        case .gummy, nil: nil
        }
    }

    // MARK: Capitals

    /// Trademark signs and footnote marks. They go, with a space in their place when a word part follows.
    private static let marks: Set<Unicode.Scalar> = ["™", "®", "©", "℠", "*", "†", "‡"]
    /// Dots that a label puts between two parts. Each one becomes a space.
    private static let dots: Set<Unicode.Scalar> = ["•", "·", "∙", "‧", "●", "|"]
    private static let separators: Set<Character> = ["-", "/", "+", "&"]
    private static let smallWords: Set<String> = ["and", "with", "of", "for", "plus", "the", "in", "from", "as", "per"]
    private static let units = ["mg": "mg", "mcg": "mcg", "g": "g", "kg": "kg", "ml": "mL", "iu": "IU", "cfu": "CFU", "oz": "oz"]

    /// Short codes and names with their own capitals.
    private static let codes: [String: String] = {
        let list = [
            "NAC", "DHA", "EPA", "ALA", "CLA", "GLA", "MSM", "SAMe", "SAM-e", "DIM", "MCT", "BCAA", "BCAAs", "EAA",
            "EAAs", "HMB", "GABA", "DHEA", "PQQ", "NMN", "NAD", "NADH", "NR", "TMG", "ZMA", "CBD", "PEA", "TUDCA",
            "HCl", "CoQ10", "Q10", "5-HTP", "HTP", "MK-7", "MK-4", "MK", "EGCG", "ALCAR", "KSM", "DGL", "HMO", "FOS",
            "GOS", "ATP", "USP", "GMO", "XL", "XR", "ER", "PM", "AM", "DNA", "RNA", "II", "III", "UC-II", "IP6",
            "mg", "mcg", "mL", "IU", "CFU", "oz", "pH", "AREDS", "ORS", "LED", "AHCC", "NAG", "CDP", "GPC", "HA",
        ]
        return Dictionary(list.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    }()

    /// One word in capitals in a readable form. Punctuation around the word stays.
    private static func readable(_ word: String, isFirst: Bool) -> String {
        let characters = Array(word)
        guard let start = characters.firstIndex(where: { $0.isLetter || $0.isNumber }),
              let end = characters.lastIndex(where: { $0.isLetter || $0.isNumber }) else { return word }
        let core = String(characters[start...end])
        var result = String(characters[..<start])
        if let code = codes[core.lowercased()] {
            result += code
        } else {
            var piece = ""
            var isFirstPiece = isFirst
            for character in core {
                if separators.contains(character) {
                    result += readablePiece(piece, isFirst: isFirstPiece) + String(character)
                    piece = ""
                    isFirstPiece = false
                } else {
                    piece.append(character)
                }
            }
            result += readablePiece(piece, isFirst: isFirstPiece)
        }
        return result + String(characters[(end + 1)...])
    }

    private static func readablePiece(_ piece: String, isFirst: Bool) -> String {
        let lowered = piece.lowercased()
        if let code = codes[lowered] { return code }
        if piece.contains(where: \.isNumber) {
            // "500MG" gets its unit. A code such as "B12" or "D3" stays.
            let digits = piece.prefix(while: { $0.isNumber || $0 == "." || $0 == "," })
            if !digits.isEmpty, let unit = units[String(lowered.dropFirst(digits.count))] { return String(digits) + unit }
            return piece
        }
        if piece.count <= 1 { return piece }
        if !isFirst, smallWords.contains(lowered) { return lowered }
        return String(piece.prefix(1)) + lowered.dropFirst()
    }

    private static let formWords: [String: LabelForm] = [
        "softgel": .softgel, "softgels": .softgel,
        "capsule": .capsule, "capsules": .capsule, "vcaps": .capsule, "vegcaps": .capsule,
        "tablet": .tablet, "tablets": .tablet, "caplet": .tablet, "caplets": .tablet,
        "powder": .powder, "powders": .powder,
        "drop": .drop, "drops": .drop,
        "gummy": .gummy, "gummies": .gummy,
    ]
}
