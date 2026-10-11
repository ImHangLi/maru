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
public enum ItemColor: String, CaseIterable, Hashable, Sendable {
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
    public var category: ItemCategory
    public private(set) var name: String
    public var form: ItemForm
    public var color: ItemColor
    public var isArchived: Bool
    /// A reference to an image file. The database stores the reference, not the image.
    public var imageReference: String?
    public var intakeNote: IntakeNote?

    public init(
        id: ItemID = ItemID(),
        category: ItemCategory,
        name: String,
        form: ItemForm,
        color: ItemColor,
        isArchived: Bool = false,
        imageReference: String? = nil,
        intakeNote: IntakeNote? = nil
    ) throws {
        self.id = id
        self.category = category
        self.name = try Self.validatedName(name)
        self.form = form
        self.color = color
        self.isArchived = isArchived
        self.imageReference = imageReference
        self.intakeNote = intakeNote
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

public enum ProductSource: String, Hashable, Sendable {
    case manual
    case labelScan
}

/// The product details that the user checked at one point in time. It is immutable.
/// A correction or a new spec creates a new `ProductVersionID`, so the past never changes (spec 7.2, T06).
/// The dose is not part of it. The dose belongs to the schedule version.
public struct ProductVersion: Hashable, Sendable {
    public let id: ProductVersionID
    public let itemID: ItemID
    public let name: String
    public let specification: String?
    public let source: ProductSource
    public let verifiedAt: Date
    public let effectiveFrom: LocalDate

    public init(
        id: ProductVersionID = ProductVersionID(),
        itemID: ItemID,
        name: String,
        specification: String? = nil,
        source: ProductSource,
        verifiedAt: Date,
        effectiveFrom: LocalDate
    ) {
        self.id = id
        self.itemID = itemID
        self.name = name
        self.specification = specification
        self.source = source
        self.verifiedAt = verifiedAt
        self.effectiveFrom = effectiveFrom
    }
}
