import Foundation
import MaruCore

/// The built-in name lists of the app, as one index for the name suggestions (D038) and the smart
/// completion of supplements (D043).
///
/// The first use reads the files and builds the index one time, off the main thread. The edit screen
/// is the first use, so the startup path does not read the lists (spec 9).
///
/// A language other than English has its own two lists, with the names that people in that market use (D069).
/// They come before the English lists, which every language keeps, because people type Latin names too.
enum NameList {
    static let index = Task.detached(priority: .userInitiated) {
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return NameIndex(
            supplements: text("SupplementNames-\(language)") + "\n" + text("SupplementNames"),
            medications: text("MedicationNames-\(language)") + "\n" + text("MedicationNames"),
            completions: text("SupplementCompletions")
        )
    }

    private static func text(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt") else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
}
