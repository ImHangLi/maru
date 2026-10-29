import Foundation
import MaruCore

extension DoseOwner {
    /// The word for "Me" before the user renames it (D121).
    static var meName: String {
        String(localized: "Me", comment: "The word for the member of the Family who owns the device, in a dose name that names its owner and in the Family pages. Example: “Me: Vitamin D3”.")
    }

    /// The name of a dose with its owner, for a surface that has one line of text: the Watch, the widgets, the Live Activity, and
    /// Siri (D123). Example: "Mochi: Methimazole". The user sees a member name there only when "Show Names in Reminders" is on and
    /// the Family has two or more active members. The Watch is the exception: it always has the names (D071).
    func label(_ name: String) -> String {
        let owner = switch self {
        case .me: Self.meName
        case let .named(name): name
        }
        return String(
            localized: "\(owner): \(name)",
            comment: "A dose name with its owner when the Family has several members. The first placeholder is the member, the second is the item name. Example: “Mochi: Methimazole”. Each language chooses its own colon."
        )
    }
}

extension TodaySnapshot.ItemLook {
    /// The name with its owner when the Family names owners, else the plain name.
    var labelledName: String { owner?.label(name) ?? name }
}
