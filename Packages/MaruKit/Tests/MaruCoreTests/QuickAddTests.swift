import Testing
@testable import MaruCore

@Suite("Quick add: label text and name suggestions (D038)")
struct QuickAddTests {
    @Test func labelTextBecomesAReadableName() {
        #expect(LabelText.clean("NATURE'S  OWN®\nOMEGA-3 FISH OIL™ 1000MG") == "Nature's Own Omega-3 Fish Oil 1000mg")
        #expect(LabelText.clean("NAC 600 MG WITH 5-HTP AND COQ10") == "NAC 600 mg with 5-HTP and CoQ10")
        #expect(LabelText.clean("L-THEANINE (B12) 2000 IU*") == "L-Theanine (B12) 2000 IU")
        // A text with a lowercase letter keeps its letters.
        #expect(LabelText.clean("Magnesium  Glycinate\t200 mg") == "Magnesium Glycinate 200 mg")
        // A removed sign does not join two parts.
        #expect(LabelText.clean("VITAMIN D3·K2 • NOW®FOODS") == "Vitamin D3 K2 Now Foods")
        #expect(LabelText.clean("Ester-C®, 90 ct") == "Ester-C, 90 ct")

        #expect(LabelText.proposedForm(from: LabelText.forms(in: "120 Soft Gels")) == .softgel)
        #expect(LabelText.proposedForm(from: LabelText.forms(in: "60 SOFTGEL CAPSULES")) == .softgel)
        #expect(LabelText.proposedForm(from: LabelText.forms(in: "Tablets or capsules")) == nil)
        #expect(LabelText.proposedForm(from: LabelText.forms(in: "90 Gummies")) == nil)
        #expect(LabelText.proposedForm(from: LabelText.forms(in: "Vitamin C")) == nil)
    }

    @Test func labelWordsChooseTheNameAndDropAmountsAndStockPhrases() {
        func chosen(_ text: String) -> String { LabelText.name(from: LabelText.words(in: text)) }
        let words = LabelText.words(in: "NATURE MADE® VITAMIN D3 1000 IU (25 mcg) Dietary Supplement 300 Softgels")
        #expect(LabelText.name(from: words) == "Nature Made Vitamin D3")
        #expect(chosen("Fish Oil 1200mg, 90ct") == "Fish Oil")
        #expect(chosen("Probiotic 50 Billion CFU Capsules") == "Probiotic")
        #expect(chosen("EXTRA STRENGTH Ester-C, 2 Pack") == "Ester-C")
        // A number with no unit after a word stays. A sign stays only between two chosen words.
        #expect(chosen("Omega 3 Fish Oil") == "Omega 3 Fish Oil")
        #expect(chosen("Vitamin D3 + K2 Gummies") == "Vitamin D3 + K2")
        #expect(chosen("NAC 600 MG WITH 5-HTP") == "NAC with 5-HTP")
        #expect(chosen("Dietary Supplement + 60 Tablets") == "")
    }

    @Test func suggestionsMatchInOrderAndIgnoreCaseAndPunctuation() {
        let index = NameIndex(supplements: """
        # A comment
        Vitamin D3 | Vit D
        Magnesium Glycinate
        Vitamin B12 | Cobalamin
        Omega-3 | Fish Oil
        Zinc
        Vitamin C + Zinc
        Rhodiola Rosea
        Açaí
        Tricalcium Phosphate
        Coral Calcium
        Calcium
        """, medications: """
        Zinc Oxide Cream
        Calcitriol
        """)
        // A match at the start, then at the start of a word, then in a word, each in the order of the list.
        #expect(index.matches("zi") == ["Zinc", "Zinc Oxide Cream", "Vitamin C + Zinc"])
        #expect(index.matches("calc") == ["Calcium", "Calcitriol", "Coral Calcium", "Tricalcium Phosphate"])
        // In one rank, the names of the type on the edit screen come first.
        #expect(index.matches("calc", category: .medication, limit: 2) == ["Calcitriol", "Calcium"])
        #expect(index.matches("b-12") == ["Vitamin B12"])
        #expect(index.matches("VIT D") == ["Vitamin D3"])
        #expect(index.matches("mag gly") == ["Magnesium Glycinate"])
        #expect(index.matches("fish") == ["Omega-3"])
        #expect(index.matches("omega3") == ["Omega-3"])
        #expect(index.matches("acai") == ["Açaí"])
        #expect(index.matches("v").isEmpty)
        #expect(index.matches("xyz").isEmpty)
        // The name in the field is not a proposal. Other capitals are.
        #expect(index.matches("Zinc") == ["Zinc Oxide Cream", "Vitamin C + Zinc"])
        #expect(index.matches("zinc") == ["Zinc", "Zinc Oxide Cream", "Vitamin C + Zinc"])
        // A name of the user's own items comes first, one time.
        #expect(index.matches("zi", ownNames: ["Vitamin C + Zinc", "Kids Zinc Drops"])
            == ["Vitamin C + Zinc", "Kids Zinc Drops", "Zinc", "Zinc Oxide Cream"])
        #expect(index.matches("vit", limit: 2) == ["Vitamin D3", "Vitamin B12"])
    }
}
