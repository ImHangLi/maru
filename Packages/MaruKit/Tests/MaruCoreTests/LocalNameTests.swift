import Foundation
import Testing
@testable import MaruCore

@Suite("Name lists in other languages (D069)")
struct LocalNameTests {
    @Test func nonLatinNamesMatchAndGetTheCompletionOfTheirTwin() {
        let index = NameIndex(supplements: """
        维生素 D | 维D | = Vitamin D
        ビタミンD | = Vitamin D
        葉酸 | ようさん
        비타민 D | = Vitamin D
        Vitamin D
        """, medications: """
        布洛芬
        アムロジピン
        """, completions: """
        Vitamin D | softgel | 1 softgel | | | label
        """)
        // One Han character is enough. Hiragana matches katakana, and a reading matches its kanji name.
        #expect(index.matches("维") == ["维生素 D"])
        #expect(index.matches("布") == ["布洛芬"])
        #expect(index.matches("あむろ") == ["アムロジピン"])
        #expect(index.matches("びたみん") == ["ビタミンD"])
        #expect(index.matches("ようさ") == ["葉酸"])
        // A voiced kana keeps its mark.
        #expect(index.matches("ひた").isEmpty)
        // A Hangul syllable that the keyboard did not complete yet matches without its last consonant.
        #expect(index.matches("비") == ["비타민 D"])
        #expect(index.matches("빝") == ["비타민 D"])
        #expect(index.matches("비ㅌ") == ["비타민 D"])
        // A local name and its alias get the completion of the English twin.
        let vitaminD = index.completion(for: "Vitamin D", category: .supplement)
        #expect(vitaminD != nil)
        for name in ["维生素 D", "维D", "ビタミンD", "びたみんD", "비타민 D"] {
            #expect(index.completion(for: name, category: .supplement) == vitaminD)
        }
    }

    /// An alias must never lead to another name: in the lists of one language with the English lists, each name and
    /// each alias belongs to one name only. The same name in both lists, or in both types, is one name.
    @Test func noLocalNameOrAliasLeadsToAnotherName() throws {
        let resources = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../../App/Resources").standardized
        func entries(_ file: String) throws -> [[String]] {
            try String(contentsOf: resources.appending(path: "\(file).txt"), encoding: .utf8)
                .split(whereSeparator: \.isNewline)
                .map { $0.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
                .filter { !$0[0].hasPrefix("#") }
        }
        func compact(_ text: String) -> String { NameIndex.words(of: text).joined() }
        let twins = Set(try entries("SupplementCompletions").map { compact($0[0]) })

        for language in ["zh-Hans", "ja", "ko", "es", "de"] {
            var owner: [String: String] = [:]
            for list in ["SupplementNames", "MedicationNames"] {
                for fields in try entries("\(list)-\(language)") + entries(list) {
                    let name = compact(fields[0])
                    for field in fields where !field.isEmpty {
                        if field.hasPrefix("=") {
                            #expect(twins.contains(compact(String(field.dropFirst()))), "\(language): \(field)")
                            continue
                        }
                        let key = compact(field)
                        #expect(owner[key, default: name] == name, "\(language): \(field)")
                        owner[key] = owner[key] ?? name
                    }
                }
            }
        }
    }
}
