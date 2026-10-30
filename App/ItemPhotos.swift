import Foundation
import ImageIO
import MaruCore
import SwiftUI
import UIKit

/// The photo files of the items (D056, spec 5.2).
///
/// The folder is next to the database, in the App Group container, with complete file protection (spec 10).
/// A file is never changed. A new photo is a new file with a new name, so the name is also the cache key,
/// and an old result can never show for a new photo. `Item.imageReference` holds the name.
enum ItemPhotos {
    /// The longest side of a stored photo in pixels (spec 5.2).
    static let maxPixel = 512
    /// The longest side of the image that a list draws, 3x of the largest list size.
    private static let thumbnailPixel = 192

    private static let directory = (AppGroup.databaseDirectory ?? AppGroup.earlierDatabaseDirectory)
        .deletingLastPathComponent()
        .appending(path: "Photos", directoryHint: .isDirectory)

    /// `NSCache` is safe to use from many threads.
    private nonisolated(unsafe) static let cache = NSCache<NSString, UIImage>()

    /// Writes a new file and returns its name.
    static func write(_ data: Data, fileExtension: String) throws -> String {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete]
        )
        let name = "\(UUID().uuidString).\(fileExtension)"
        try data.write(to: directory.appending(path: name), options: [.atomic, .completeFileProtection])
        return name
    }

    /// Writes a copy of a stored file with a new name, and returns the name. `nil` when the file is missing or unreadable.
    static func copy(_ name: String) -> String? {
        guard let url = url(name), let data = try? Data(contentsOf: url) else { return nil }
        return try? write(data, fileExtension: url.pathExtension)
    }

    static func remove(_ name: String?) {
        guard let url = url(name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Removes every file that no item refers to, for example after a restore replaced the items (D040).
    static func removeAll(keeping names: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !names.contains(file) {
            remove(file)
        }
    }

    /// The image that a list draws, from the cache or from the file. `nil` when the file is missing or cannot
    /// be read, for example while the iPhone is locked. The caller then shows the form icon.
    /// The read runs off the main actor (spec 9).
    static func thumbnail(_ name: String) async -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let url = url(name) else { return nil }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: thumbnailPixel,
            ]
            return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map { UIImage(cgImage: $0) }
        }.value
        if let image { cache.setObject(image, forKey: name as NSString) }
        return image
    }

    static func cached(_ name: String) -> UIImage? {
        cache.object(forKey: name as NSString)
    }

    /// The file of a name. A name with a path part gives `nil`, so a stored value cannot point outside the folder.
    private static func url(_ name: String?) -> URL? {
        guard let name, !name.isEmpty, name == (name as NSString).lastPathComponent, name != ".." else { return nil }
        return directory.appending(path: name)
    }
}

extension AppStore {
    func writePhoto(_ data: Data, fileExtension: String) throws -> String {
        try ItemPhotos.write(data, fileExtension: fileExtension)
    }

    func copyPhoto(_ name: String) -> String? {
        ItemPhotos.copy(name)
    }

    func removePhoto(_ name: String?) {
        ItemPhotos.remove(name)
    }

    /// Removes the photo files that no stored item and no member of the Family uses (D124). A debug scenario has its own items, so
    /// it keeps the files.
    func removeUnreferencedPhotos() async {
        #if DEBUG
        guard DebugStore.directory == nil else { return }
        #endif
        guard let store = try? open(), let items = try? await store.items(), let people = try? await store.people() else { return }
        ItemPhotos.removeAll(keeping: Set(items.compactMap(\.imageReference) + people.compactMap(\.imageReference)))
    }
}

/// The photo of an item, or `fallback` while it loads and when it is missing (spec 5.1, T32).
/// A list shows the form icon first, and the photo replaces it when the read ends. The read never blocks the view.
struct ItemPhotoView<Fallback: View>: View {
    let reference: String?
    let side: CGFloat
    private let fallback: Fallback
    @State private var loaded: UIImage?

    init(reference: String?, side: CGFloat, @ViewBuilder fallback: () -> Fallback) {
        self.reference = reference
        self.side = side
        self.fallback = fallback()
    }

    var body: some View {
        Group {
            if let image = reference.flatMap(ItemPhotos.cached) ?? loaded {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: side / 5, style: .continuous))
            } else {
                fallback
            }
        }
        .task(id: reference) {
            loaded = nil
            guard let reference else { return }
            loaded = await ItemPhotos.thumbnail(reference)
        }
    }
}
