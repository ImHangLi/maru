import Foundation
import Testing
@testable import MaruCore

@Suite("Scope and item color (spec 1, D021)")
struct ModelRuleTests {
    // MARK: Item color (D021)

    @Test func newItemGetsTheFirstColorThatNoActiveItemUses() throws {
        func item(_ color: ItemColor, archived: Bool = false) throws -> Item {
            try Item(personID: PersonID(), category: .supplement, name: "Zinc", form: .tablet, color: color, isArchived: archived)
        }
        #expect(ItemColor.forNewItem(among: []) == .pink)
        // An archived item does not hold its color.
        #expect(ItemColor.forNewItem(among: [try item(.pink), try item(.yellow), try item(.orange, archived: true)]) == .orange)
        let all = try ItemColor.allCases.map { try item($0) }
        #expect(ItemColor.forNewItem(among: all) == .pink)
    }
}
