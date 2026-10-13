import Foundation

/// The built-in lists of common supplement and medicine names, ready for a search while the user types (D038).
///
/// A match proposes a name and nothing else: no type, no amount, and no time. The lists are a typing aid.
/// They are not medical information. A third list gives the smart completion of common supplements (D043).
/// The app gives the lists of its language first, then the English lists, because people type Latin names
/// too (D070). Build the index one time, off the main thread. A search reads it and is quick enough for each
/// key press.
public struct NameIndex: Sendable {
    /// A name or an alias in the form that the search compares.
    private struct Key: Sendable {
        /// The letters and digits in lowercase with no accent: "Vitamin B-12" is "vitaminb12".
        let compact: String
        /// The words of the name, in the same form.
        let words: [String]

        init(_ text: String) {
            words = NameIndex.words(of: text)
            compact = words.joined()
        }

        /// 0 for a match at the start, 1 for a match at the start of a later word, 2 for a match in a word.
        func rank(of query: Key) -> Int? {
            if compact.hasPrefix(query.compact) { return 0 }
            if query.words.count > 1, let first = wordsMatch(query.words) { return first == 0 ? 0 : 1 }
            var rest = Substring(compact)
            for word in words.dropLast() {
                rest = rest.dropFirst(word.count)
                if rest.hasPrefix(query.compact) { return 1 }
            }
            return compact.contains(query.compact) ? 2 : nil
        }

        /// Each word of the query starts one word of the name, in the same order: "mag gly" for
        /// "Magnesium Glycinate". It returns the position of the first matched word.
        private func wordsMatch(_ queryWords: [String]) -> Int? {
            var next = 0
            var first: Int?
            for queryWord in queryWords {
                guard let found = words[next...].firstIndex(where: { $0.hasPrefix(queryWord) }) else { return nil }
                if first == nil { first = found }
                next = found + 1
            }
            return first
        }
    }

    private struct Entry: Sendable {
        let name: String
        let category: ItemCategory
        let keys: [Key]
        /// The English name with the same smart completion, in compact form, for a name in another language.
        let twin: String?

        /// A match in the name counts in full. An alias counts one rank lower, and only from the start of
        /// a word, because the row shows the name and not the alias.
        func rank(of query: Key) -> Int? {
            var best = keys.first?.rank(of: query)
            for alias in keys.dropFirst() {
                guard let rank = alias.rank(of: query), rank < 2 else { continue }
                best = min(best ?? 2, rank + 1)
            }
            return best
        }
    }

    private let entries: [Entry]
    /// The smart completion of each supplement, by the compact form of its name.
    private let completions: [String: SmartCompletion]

    /// Reads the lists. In the name lists, each line is one name, then its aliases after "|". The order is
    /// from the most common name down. A field that starts with "=" is not an alias: it names the English
    /// twin of a name in another language. In the completion list, each line is a name and its fields after "|".
    /// A line that starts with "#" is a comment.
    public init(supplements: String, medications: String = "", completions: String = "") {
        entries = Self.entries(in: supplements, category: .supplement)
            + Self.entries(in: medications, category: .medication)
        self.completions = Dictionary(
            Self.lines(of: completions).map { (Key($0[0]).compact, SmartCompletion(fields: $0)) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func lines(of list: String) -> [[String]] {
        list.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard let name = fields.first, !name.isEmpty, !name.hasPrefix("#") else { return nil }
            return fields
        }
    }

    private static func entries(in list: String, category: ItemCategory) -> [Entry] {
        lines(of: list).map { fields in
            let twin = fields.first { $0.hasPrefix("=") }.map { Key(String($0.dropFirst())).compact }
            let keys = fields.filter { !$0.isEmpty && !$0.hasPrefix("=") }.map(Key.init)
            return Entry(name: fields[0], category: category, keys: keys, twin: twin)
        }
    }

    /// The smart completion for the name in the field (D043).
    ///
    /// Only for a supplement: the type on the screen is "Supplement", and the name is a supplement name or one
    /// of its aliases, in full. The match ignores case, accents, spaces, hyphens, and dots. A name that is also
    /// a medicine name gets none, and so does a longer name such as a brand with a supplement name in it.
    /// A name in another language gets the completion of its English twin, and no data of its own (D070).
    public func completion(for text: String, category: ItemCategory) -> SmartCompletion? {
        guard category == .supplement else { return nil }
        let query = Key(text).compact
        guard !query.isEmpty else { return nil }
        var listName: String?
        for entry in entries where entry.keys.contains(where: { $0.compact == query }) {
            guard entry.category == .supplement else { return nil }
            if listName == nil { listName = entry.twin ?? entry.keys.first?.compact }
        }
        return completions[listName ?? query]
    }

    /// The names to propose for the text in the name field.
    ///
    /// The search ignores case, accents, spaces, hyphens, and dots. It needs two letters or digits, or one
    /// character of Chinese, Japanese, or Korean. Hiragana matches katakana, and a Hangul syllable that the
    /// keyboard did not complete yet matches without its last consonant (D070).
    /// A name of the user's own items comes first. Then come the matches at the start of a name, the matches
    /// at the start of a word, and the matches in a word, each in the order of the list.
    /// In one rank, the names of the type that the edit screen shows come first. The type only orders
    /// the result: a proposal never changes the type.
    /// A name that the field already shows is not in the result.
    public func matches(
        _ text: String,
        category: ItemCategory = .supplement,
        ownNames: [String] = [],
        limit: Int = 4
    ) -> [String] {
        let query = Key(text)
        guard query.compact.count >= 2 || query.compact.unicodeScalars.contains(where: { $0.value >= 0x1100 }),
              limit > 0 else { return [] }
        let found = names(for: query, typed: text, category: category, ownNames: ownNames, limit: limit)
        guard found.isEmpty, let open = Self.withoutOpenConsonant(query.compact) else { return found }
        return names(for: Key(open), typed: text, category: category, ownNames: ownNames, limit: limit)
    }

    private func names(for query: Key, typed text: String, category: ItemCategory, ownNames: [String], limit: Int) -> [String] {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var seen: Set<String> = []
        var found: [(rank: Int, name: String)] = []
        func add(_ entry: Entry, base: Int) {
            guard let rank = entry.rank(of: query), entry.name != typed,
                  let compact = entry.keys.first?.compact, seen.insert(compact).inserted else { return }
            let isOtherType = category != .unknown && entry.category != category
            found.append((base + rank * 2 + (isOtherType ? 1 : 0), entry.name))
        }
        for name in ownNames {
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            add(Entry(name: name, category: category, keys: [Key(name)], twin: nil), base: -6)
        }
        for entry in entries { add(entry, base: 0) }

        // The sort keeps the order of the lists in each rank.
        return found.enumerated()
            .sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) }
            .prefix(limit)
            .map(\.element.name)
    }

    /// The text while a Korean keyboard composes a syllable: "빝" on the way from "비" to "비타", or "비ㅌ".
    /// It returns the text without the last consonant, or `nil` when the last character is complete.
    private static func withoutOpenConsonant(_ text: String) -> String? {
        guard let last = text.unicodeScalars.last?.value else { return nil }
        let rest = String(text.dropLast())
        // A consonant alone, from the compatibility jamo block.
        if (0x3131...0x314E).contains(last) { return rest.isEmpty ? nil : rest }
        // A syllable is 0xAC00 + (initial * 21 + vowel) * 28 + final. A final of 0 is no last consonant.
        guard (0xAC00...0xD7A3).contains(last), (last - 0xAC00) % 28 != 0 else { return nil }
        return rest + String(UnicodeScalar(last - (last - 0xAC00) % 28)!)
    }

    /// The words of a text in the form that the search compares: lowercase, no accent, full-width letters as
    /// plain letters, and hiragana as katakana. A voiced kana keeps its mark: "バ" is not "ハ".
    static func words(of text: String) -> [String] {
        let plain = text.folding(options: [.caseInsensitive, .widthInsensitive], locale: nil)
            .applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        return plain.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { word in
                word.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
                    ? String(word)
                    : word.folding(options: .diacriticInsensitive, locale: nil)
            }
    }
}
