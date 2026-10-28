import Foundation
import MaruCore

/// What the app and the widgets share through the App Group (D048).
///
/// A build with no App Group entitlement, for example the CI build with no signing, has no container.
/// The app then keeps its database where it was, and it has no widget data.
enum AppGroup {
    static let identifier = "group.com.imhangli.maru"

    /// The `UserDefaults` of the group, or the standard ones when the build has no group.
    static var defaults: UserDefaults { UserDefaults(suiteName: identifier) ?? .standard }

    /// The directory of the database in the container, or `nil` when the build has no container.
    static var databaseDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)?
            .appending(path: "Database", directoryHint: .isDirectory)
    }

    /// The directory of the database before the move to the container (D048).
    static var earlierDatabaseDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Database", directoryHint: .isDirectory)
    }

    private static let appColorKey = "display.appColor"

    /// The app tint for the widgets. The app writes it when the user picks a color (D025). It is no health data.
    static var appColor: ItemColor {
        get { UserDefaults(suiteName: identifier)?.string(forKey: appColorKey).flatMap(ItemColor.init) ?? .pink }
        set { UserDefaults(suiteName: identifier)?.set(newValue.rawValue, forKey: appColorKey) }
    }

    private static let showsNamesKey = "reminders.showsNames"

    /// "Show Names in Reminders" for the "Last Dose" widget (D029, D108). The app writes it at each launch and at each
    /// change. No value hides the names, so a widget that runs before the app writes it shows no name.
    static var showsNames: Bool {
        get { UserDefaults(suiteName: identifier)?.bool(forKey: showsNamesKey) ?? false }
        set { UserDefaults(suiteName: identifier)?.set(newValue, forKey: showsNamesKey) }
    }

    /// The link of a tap on a widget. Today opens at the slot (D048).
    static func todayURL(_ part: DayPart?) -> URL {
        URL(string: "maru://today" + (part.map { "/" + $0.linkName } ?? ""))!
    }

    /// The link of a tap on the "Last Dose" widget. Today opens the detail of the item (D108).
    static func itemURL(_ id: ItemID) -> URL {
        URL(string: "maru://item/" + id.rawValue.uuidString)!
    }
}

extension DayPart {
    /// The name of the slot in a link from a widget.
    var linkName: String {
        switch self {
        case .morning: "morning"
        case .noon: "noon"
        case .evening: "evening"
        }
    }

    init?(linkName: String) {
        guard let part = Self.allCases.first(where: { $0.linkName == linkName }) else { return nil }
        self = part
    }
}
