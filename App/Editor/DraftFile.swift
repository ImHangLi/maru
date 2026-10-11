import Foundation

/// The unsaved draft of the edit screen in a file, so the user gets it back after the app stops (spec 3 P03).
///
/// The draft can hold a medication name, so the file stays on the device with complete file protection (spec 10).
/// There is one file for a new item and one file for each item in edit.
enum DraftFile {
    private static let realDirectory = URL.applicationSupportDirectory.appending(path: "Drafts", directoryHint: .isDirectory)

    /// The drafts of the store that the app uses. A debug store has its own drafts, so a draft of test data
    /// never shows with the real list, and a debug reset deletes only test drafts.
    private static var directory: URL {
        #if DEBUG
        DebugStore.drafts ?? realDirectory
        #else
        realDirectory
        #endif
    }

    static func load(key: String) -> ItemDraft? {
        guard let data = try? Data(contentsOf: url(key)) else { return nil }
        return try? JSONDecoder().decode(ItemDraft.self, from: data)
    }

    /// A failure only means that the draft is not kept. The edit screen still has it.
    static func save(_ draft: ItemDraft, key: String) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        let url = url(key)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    static func remove(key: String) {
        try? FileManager.default.removeItem(at: url(key))
    }

    private static func url(_ key: String) -> URL {
        directory.appending(path: "\(key).json")
    }
}
