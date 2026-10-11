import Foundation

/// The built-in lists of common supplement and medicine names, ready for a search while the user types (D038).
///
/// The lists hold names only. A match proposes a name and nothing else: no type, no amount, and no time.
/// The lists are a typing aid. They are not medical information.
/// Build the index one time, off the main thread. A search reads it and is quick enough for each key press.
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

    /// Reads the two lists. Each line is one name, then its aliases after "|". The order is from the most
    /// common name down. A line that starts with "#" is a comment.
    public init(supplements: String, medications: String = "") {
        entries = Self.entries(in: supplements, category: .supplement)
            + Self.entries(in: medications, category: .medication)
    }

    private static func entries(in list: String, category: ItemCategory) -> [Entry] {
        list.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let name = fields.first, !name.isEmpty, !name.hasPrefix("#") else { return nil }
            return Entry(name: name, category: category, keys: fields.map(Key.init))
        }
    }

    /// The names to propose for the text in the name field.
    ///
    /// The search ignores case, accents, spaces, hyphens, and dots. It needs two letters or digits.
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
        guard query.compact.count >= 2, limit > 0 else { return [] }
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
            add(Entry(name: name, category: category, keys: [Key(name)]), base: -6)
        }
        for entry in entries { add(entry, base: 0) }

        // The sort keeps the order of the lists in each rank.
        return found.enumerated()
            .sorted { ($0.element.rank, $0.offset) < ($1.element.rank, $1.offset) }
            .prefix(limit)
            .map(\.element.name)
    }

    private static func words(of text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}
