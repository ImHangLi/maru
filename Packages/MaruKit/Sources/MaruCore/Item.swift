import Foundation

public enum ItemError: Error, Equatable, Sendable {
    case blankName
    case blankNote
}

public enum ItemCategory: String, CaseIterable, Hashable, Sendable {
    case supplement
    case medication
    /// The user did not say. Treat it with the care of a medication.
    case unknown
}

/// The dosage form that the user picked. The app does not guess it (D013).
public enum ItemForm: String, CaseIterable, Hashable, Sendable {
    case capsule
    case tablet
    case softgel
    case powder
    case drop
    /// The user did not say. The row shows a jar.
    case unknown
}

/// The color of an item. It appears only on the form icon (D021).
/// The case order is the order of the color row on the edit screen.
public enum ItemColor: String, CaseIterable, Hashable, Sendable, Codable {
    case pink
    case orange
    case yellow
    case green
    case mint
    case blue
    case purple
    case brown

    /// The color for a new item: the first color in the row that no active item uses, else pink.
    /// The user can change it on the same edit screen (D021).
    public static func forNewItem(among items: some Sequence<Item>) -> ItemColor {
        let used = Set(items.lazy.filter { !$0.isArchived }.map(\.color))
        return allCases.first { !used.contains($0) } ?? .pink
    }
}

/// A note that the user wrote about how they take an item, for example "with food".
/// It is the user's own text, not app advice (D006).
public enum IntakeNote: Hashable, Sendable {
    public enum Preset: String, CaseIterable, Hashable, Sendable {
        case withFood
        case emptyStomach
    }

    case preset(Preset)
    case text(String)

    /// Free text. Blank text is rejected.
    public static func custom(_ text: String) throws -> IntakeNote {
        guard !text.allSatisfy(\.isWhitespace) else { throw ItemError.blankNote }
        return .text(text)
    }
}

/// One supplement or medication in the user's list. It has no inventory fields (spec 1, T09).
public struct Item: Hashable, Sendable {
    public let id: ItemID
    /// The member of the Family that owns the item (D121). Every item has exactly one owner.
    public var personID: PersonID
    public var category: ItemCategory
    public private(set) var name: String
    public var form: ItemForm
    public var color: ItemColor
    public var isArchived: Bool
    public var intakeNote: IntakeNote?
    /// The name of the photo file that the app keeps for this item, or `nil` for no photo (D056).
    /// The core keeps only the name. The app owns the file, and a missing file shows the form icon.
    public var imageReference: String?
    /// The follow-ups of this item (D039, D079). `nil` means off, which is the default.
    public var followUp: FollowUpSetting?
    /// The time of the last change of `followUp`. `nil` when no change is known. The plan counts the follow-ups
    /// that a dose can have got before this time, so a change never lifts the limit of one dose (D039).
    public var followUpChanged: Date?
    /// The dose time rings as an alarm (D079). Off is the default.
    public var alarm: Bool
    /// The instant of the archive (D091). `nil` for an item that is not archived, and for an item archived before the
    /// app kept it. History plans the doses with no record of an archived item only up to the day of its archive.
    public var archivedAt: Date?
    /// The usual amount of an item that is as needed (D091). A dose that the user records copies it. `nil` means no
    /// amount. An item with a time has its amount in its schedule.
    public var asNeededDose: Dose?
    /// The instant of the last change of `personID` (D123). A quick action that was listed before it records nothing,
    /// because the user saw another owner. The store sets it. `nil` for an item that never changed its owner.
    public var ownerChangedAt: Date?


    public init(
        id: ItemID = ItemID(),
        personID: PersonID,
        category: ItemCategory,
        name: String,
        form: ItemForm,
        color: ItemColor,
        isArchived: Bool = false,
        intakeNote: IntakeNote? = nil,
        imageReference: String? = nil,
        followUp: FollowUpSetting? = nil,
        followUpChanged: Date? = nil,
        alarm: Bool = false,
        archivedAt: Date? = nil,
        asNeededDose: Dose? = nil,
        ownerChangedAt: Date? = nil
    ) throws {
        self.id = id
        self.personID = personID
        self.category = category
        self.name = try Self.validatedName(name)
        self.form = form
        self.color = color
        self.isArchived = isArchived
        self.intakeNote = intakeNote
        self.imageReference = imageReference
        self.followUp = followUp
        self.followUpChanged = followUpChanged
        self.alarm = alarm
        self.archivedAt = archivedAt
        self.asNeededDose = asNeededDose
        self.ownerChangedAt = ownerChangedAt
    }

    public mutating func rename(_ name: String) throws {
        self.name = try Self.validatedName(name)
    }

    private static func validatedName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ItemError.blankName }
        return trimmed
    }
}
