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

/// A word of a tapped text on the scan card (D042). A tap on the card adds it to the name or removes it.
public struct LabelWord: Hashable, Sendable {
    public let text: String
    public var isChosen: Bool

    public init(text: String, isChosen: Bool) {
        self.text = text
        self.isChosen = isChosen
    }
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
        var words = plainWords(text)
        let letters = words.joined().filter(\.isLetter)
        if !letters.isEmpty, !letters.contains(where: \.isLowercase) {
            words = words.enumerated().map { readable($0.element, isFirst: $0.offset == 0) }
        }
        return words.joined(separator: " ")
    }

    /// The words of a text with no trademark signs, footnote marks, or dots between parts. The letters stay.
    private static func plainWords(_ text: String) -> [String] {
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
        return String(plain).split(separator: " ").map(String.init)
    }

    /// The words of one tapped text, in reading order, with the letters of the label (D042). The words that
    /// look like the name are chosen:
    ///
    /// - A number with a unit or a count is not chosen: "1000 IU", "5mg", "60 Softgels", "90ct".
    /// - A stock phrase of a label is not chosen: "Dietary Supplement", "Capsules", "High Potency".
    /// - A number with no unit is chosen only after a chosen word: "Omega 3".
    /// - A sign such as "+" is chosen only between two chosen words: "D3 + K2".
    /// - Each other word is chosen.
    public static func words(in text: String) -> [LabelWord] {
        let texts = plainWords(text).compactMap { word -> String? in
            let text = String(word.reversed().drop(while: { trailingMarks.contains($0) }).reversed())
            return text.isEmpty ? nil : text
        }
        let keys = texts.map(key)
        var stock = Array(repeating: false, count: keys.count)
        var index = 0
        while index < keys.count {
            let phrase = stockPhrases.first { phrase in
                index + phrase.count <= keys.count && Array(keys[index..<(index + phrase.count)]) == phrase
            }
            let length = phrase?.count ?? 1
            if phrase != nil { stock.replaceSubrange(index..<(index + length), with: repeatElement(true, count: length)) }
            index += length
        }

        var chosen = Array(repeating: true, count: keys.count)
        for index in keys.indices {
            let key = keys[index]
            let previous = index > 0 ? keys[index - 1] : nil
            if stock[index] || isQuantity(key) {
                chosen[index] = false
            } else if isNumber(key) {
                let next = index + 1 < keys.count ? index + 1 : nil
                let unitFollows = next.map { stock[$0] || unitWords.contains(keys[$0]) || isQuantity(keys[$0]) } ?? false
                chosen[index] = index > 0 && chosen[index - 1] && !unitFollows
            } else if unitWords.contains(key), let previous, isNumber(previous) || unitWords.contains(previous) {
                chosen[index] = false
            }
        }
        // A sign needs the choice of the word after it.
        for index in keys.indices where keys[index].isEmpty {
            chosen[index] = index > 0 && index + 1 < keys.count && chosen[index - 1] && chosen[index + 1]
        }
        return zip(texts, chosen).map { LabelWord(text: $0, isChosen: $1) }
    }

    /// The name from the chosen words, in the order of the card, cleaned as one text.
    public static func name(from words: [LabelWord]) -> String {
        clean(words.filter(\.isChosen).map(\.text).joined(separator: " "))
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

    // MARK: Words

    /// The stock phrases of a label. A word in one of them is not chosen for the name (D042).
    /// A longer phrase comes before a phrase that is a part of it.
    private static let stockPhrases: [[String]] = [
        "dietary supplement", "high potency", "extra strength", "maximum strength", "soft gels",
        "supplement", "supplements", "capsule", "capsules", "caps", "vcaps", "softgel", "softgels", "tablet",
        "tablets", "caplet", "caplets", "gummy", "gummies", "serving", "servings", "supports", "count", "ct",
        "net", "value", "pack", "bottle", "formula", "advanced",
    ].map { $0.split(separator: " ").map(String.init) }
    /// Units after a number: "1000 IU", "50 Billion CFU".
    private static let unitWords = Set(units.keys).union(["µg", "billion", "million", "fl"])
    /// The end of a number and its unit in one word: "5mg", "90ct", "2x".
    private static let quantityEnds = unitWords.union(["ct", "x", "pk"])
    /// Punctuation at the end of a word that is not a part of the name: "Ester-C," is "Ester-C".
    private static let trailingMarks: Set<Character> = [",", ";", ":"]

    /// A word in lowercase, with no punctuation at its start or end. A sign such as "+" gives "".
    private static func key(_ word: String) -> String {
        let characters = Array(word.lowercased())
        guard let start = characters.firstIndex(where: { $0.isLetter || $0.isNumber }),
              let end = characters.lastIndex(where: { $0.isLetter || $0.isNumber }) else { return "" }
        return String(characters[start...end])
    }

    /// "60", "1,000", or "2.5".
    private static func isNumber(_ key: String) -> Bool {
        key.first?.isNumber == true && key.allSatisfy { $0.isNumber || $0 == "." || $0 == "," }
    }

    /// A number and its unit or count in one word: "5mg", "2000iu", "90ct".
    private static func isQuantity(_ key: String) -> Bool {
        let digits = key.prefix { $0.isNumber || $0 == "." || $0 == "," }
        return !digits.isEmpty && quantityEnds.contains(String(key.dropFirst(digits.count)))
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
