import Foundation
import Testing
@testable import MaruCore

@Suite("Preferences, scope, and item color (spec 1, 8.2, 11.3, D021)")
struct ModelRuleTests {
    // MARK: Preferences

    @Test func defaultPreferencesAreConservative() {
        #expect(Preferences.default.analyticsConsent == .notAsked)
    }

    // MARK: No inventory (spec 1, T09)

    @Test func noTypeCarriesInventoryFields() throws {
        let (schedule, _, _) = Fixtures.twiceDailySchedule()
        let occurrence = Fixtures.occurrence()
        let values: [Any] = [
            Fixtures.item(),
            ProductVersion(itemID: Fixtures.item().id, name: "D3", source: .manual, verifiedAt: Date(), effectiveFrom: Fixtures.date(2026, 1, 1)),
            schedule,
            try #require(schedule.versions.first),
            occurrence,
            Fixtures.event(for: occurrence, .taken),
            Preferences.default,
        ]
        let banned = ["inventory", "stock", "remaining", "bottle", "supply", "refill", "quantity", "count", "pills"]
        for value in values {
            for child in Mirror(reflecting: value).children {
                let label = (child.label ?? "").lowercased()
                #expect(!banned.contains { label.contains($0) }, "\(type(of: value)).\(label)")
            }
        }
    }

    // MARK: Item color (D021)

    @Test func newItemGetsTheFirstColorThatNoActiveItemUses() throws {
        func item(_ color: ItemColor, archived: Bool = false) throws -> Item {
            try Item(category: .supplement, name: "Zinc", form: .tablet, color: color, isArchived: archived)
        }
        #expect(ItemColor.forNewItem(among: []) == .pink)
        // An archived item does not hold its color.
        #expect(ItemColor.forNewItem(among: [try item(.pink), try item(.yellow), try item(.orange, archived: true)]) == .orange)
        let all = try ItemColor.allCases.map { try item($0) }
        #expect(ItemColor.forNewItem(among: all) == .pink)
    }
}
