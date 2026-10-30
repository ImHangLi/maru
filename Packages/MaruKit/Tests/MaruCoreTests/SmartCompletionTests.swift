import Testing
@testable import MaruCore

@Suite("Smart completion for supplements (D043)")
struct SmartCompletionTests {
    @Test func onlyASupplementNameGetsCandidatesAndNothingOverwritesTheUser() throws {
        let index = NameIndex(supplements: """
        Magnesium Glycinate | Mag Glycinate
        Fish Oil
        Zinc
        """, medications: """
        Zinc
        Metformin
        """, completions: """
        # name | form | amounts | times | note | source
        Magnesium Glycinate | capsule | 1 capsule; 2 capsules | evening | | label
        Fish Oil | softgel | 1 softgel; 2 softgels | | with food | label
        Zinc | tablet | 1 tablet | | | label
        Metformin | tablet | 1 tablet | | | label
        """)
        let magnesium = SmartCompletion(form: .capsule, amounts: ["1 capsule", "2 capsules"], times: [.evening])
        // A full name or an alias matches. Case, spaces, and hyphens do not count.
        #expect(index.completion(for: "magnesium-glycinate ", category: .supplement) == magnesium)
        #expect(index.completion(for: "Mag Glycinate", category: .supplement) == magnesium)
        #expect(index.completion(for: "Fish Oil", category: .supplement)?.notes == [.preset(.withFood)])
        // A medication, a name that is also a medicine name, and a longer name get nothing.
        #expect(index.completion(for: "Fish Oil", category: .medication) == nil)
        #expect(index.completion(for: "Zinc", category: .supplement) == nil)
        #expect(index.completion(for: "Metformin", category: .supplement) == nil)
        #expect(index.completion(for: "Kids Fish Oil", category: .supplement) == nil)

        // The candidates hide what the draft already has. An amount that the user typed hides the amounts.
        let evening = try WallClockTime(hour: 21, minute: 30)
        #expect(magnesium.open(amount: "", times: [], hasNote: false) == magnesium)
        #expect(magnesium.open(amount: "1 Capsule", times: [evening], hasNote: true)
            == SmartCompletion(form: .capsule, amounts: ["2 capsules"]))
        #expect(magnesium.open(amount: "200 mg", times: [], hasNote: false).amounts.isEmpty)
        // A time reuses a supplement time that the user confirmed in that part of the day.
        #expect(DayPart.evening.time(confirmed: [try WallClockTime(hour: 8, minute: 0), evening]) == evening)

        // The form changes by itself only before the user chooses one. The label form comes first.
        #expect(SmartCompletion.formStep(usual: .softgel, scanned: nil, current: .capsule, mayChange: true) == .set(.softgel))
        #expect(SmartCompletion.formStep(usual: .softgel, scanned: nil, current: .capsule, mayChange: false) == .propose(.softgel))
        #expect(SmartCompletion.formStep(usual: .softgel, scanned: .tablet, current: .capsule, mayChange: true) == .set(.tablet))
        #expect(SmartCompletion.formStep(usual: .softgel, scanned: nil, current: .softgel, mayChange: false) == .none)
    }
}
