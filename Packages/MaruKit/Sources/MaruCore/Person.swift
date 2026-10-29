import Foundation

public typealias PersonID = Identifier<Person>

/// What a member of the Family is (D121). `me` is the one member that every database has.
public enum PersonKind: String, CaseIterable, Hashable, Sendable {
    case me
    case person
    case pet
}

/// The animal of a pet (D121). The raw values are the stored words. The app maps them to symbols.
public enum PetSymbol: String, CaseIterable, Hashable, Sendable {
    case dog
    case cat
    case bird
    case rabbit
    case fish
    case paw
}

public enum PersonError: Error, Equatable, Sendable {
    case blankName
    /// Only `me` can have no name.
    case nameRequired
    /// Only a pet has an animal.
    case symbolForPetOnly
}

/// One member of the Family: a person or a pet on this iPhone (D121). A member is a local label. It is not an account
/// and not a health profile (spec 1).
///
/// An item belongs to exactly one member (`Item.personID`). Schedules, versions, occurrences, and events belong to a member
/// through their item, so no other record holds a member ID.
public struct Person: Hashable, Sendable {
    public let id: PersonID
    public private(set) var kind: PersonKind
    /// `nil` only for `me` that the user did not rename. The app shows its own word for it.
    public private(set) var name: String?
    /// The avatar animal of a pet. `nil` for `me` and for a person: their avatar is a person symbol or the initial of the name.
    public private(set) var symbol: PetSymbol?
    /// The color of the avatar (D128). `nil` uses the app color, as "Me" always does.
    public var color: ItemColor?
    /// The name of a photo file that the user chose from the library or took with the camera (D124). The app stores the file as the
    /// photo of an item (D056). The avatar shows the photo when the file is on the iPhone, else the symbol or the initial.
    public var imageReference: String?
    /// The instant of the archive (D125). An item that was archived with the member has the same instant.
    public var archivedAt: Date?

    public init(
        id: PersonID = PersonID(),
        kind: PersonKind,
        name: String?,
        symbol: PetSymbol? = nil,
        color: ItemColor? = nil,
        imageReference: String? = nil,
        archivedAt: Date? = nil
    ) throws {
        self.id = id
        self.kind = kind
        self.name = try Self.validated(name, kind: kind)
        self.symbol = try Self.validated(symbol, kind: kind)
        self.color = color
        self.imageReference = imageReference
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }

    /// A new name. A blank name is rejected. The name of `me` can come back to `nil` only through `init`.
    public mutating func rename(_ name: String) throws {
        self.name = try Self.validated(name, kind: kind)
    }

    /// Changes between `person` and `pet`. `me` stays `me`. A person has no animal.
    public mutating func become(_ kind: PersonKind, symbol: PetSymbol?) throws {
        guard self.kind != .me, kind != .me else { return }
        let checked = try Self.validated(symbol, kind: kind)
        self.kind = kind
        self.symbol = checked
    }

    private static func validated(_ name: String?, kind: PersonKind) throws -> String? {
        guard let name else {
            guard kind == .me else { throw PersonError.nameRequired }
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonError.blankName }
        return trimmed
    }

    private static func validated(_ symbol: PetSymbol?, kind: PersonKind) throws -> PetSymbol? {
        guard symbol == nil || kind == .pet else { throw PersonError.symbolForPetOnly }
        return symbol
    }
}

extension ItemColor {
    /// The color of a new member: the first color in the row that no other member uses, and not the app color when another color
    /// is free (D128). The user can change it on the page of the member.
    public static func forNewMember(among people: some Sequence<Person>, appColor: ItemColor) -> ItemColor {
        let used = Set(people.compactMap(\.color))
        let free = allCases.filter { !used.contains($0) }
        return free.first { $0 != appColor } ?? free.first ?? allCases.first { $0 != appColor } ?? .blue
    }
}

/// What a text needs from the owner of a dose. The notification target and the app turn `.me` into their own word (D123).
public enum DoseOwner: Hashable, Sendable {
    case me
    case named(String)
}

/// The members of the Family, as the plans and the texts of the reminders read them (D123).
///
/// A member is named in a text only when the Family has two or more active members. With one active member, every text
/// stays as it was before the Family (T57). The lookup holds no clock and reads no system state.
public struct Family: Hashable, Sendable {
    public let people: [Person]

    public init(people: [Person] = []) {
        self.people = people
    }

    public var activeCount: Int { people.filter { !$0.isArchived }.count }

    /// Two or more active members: texts name the owner, and a group action cannot cross members.
    public var namesOwners: Bool { activeCount >= 2 }

    /// The owner for a text, or `nil` when the Family has one active member or the item has an unknown owner.
    public func owner(of item: Item) -> DoseOwner? {
        owner(of: item.personID)
    }

    public func owner(of id: PersonID) -> DoseOwner? {
        guard namesOwners, let person = people.first(where: { $0.id == id }) else { return nil }
        return person.name.map(DoseOwner.named) ?? .me
    }
}

/// One entry of a reminder text: an item name, and its owner when the Family names owners (D123).
public struct ReminderName: Hashable, Sendable, ExpressibleByStringLiteral {
    public let item: String
    public let owner: DoseOwner?

    public init(item: String, owner: DoseOwner? = nil) {
        self.item = item
        self.owner = owner
    }

    /// An item with no owner name.
    public init(stringLiteral value: String) {
        self.init(item: value)
    }

    /// The text of an identifier, for example the identifier of an alarm. It changes with the item name and with the owner.
    var key: String {
        switch owner {
        case nil: item
        case .me?: "me\u{1F}" + item
        case let .named(name)?: "named\u{1F}" + name + "\u{1F}" + item
        }
    }
}
