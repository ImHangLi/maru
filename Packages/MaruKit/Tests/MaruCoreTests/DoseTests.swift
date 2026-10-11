import Foundation
import Testing
@testable import MaruCore

@Suite("Dose is optional free text with no default (spec 2.1, 7.2)")
struct DoseTests {
    @Test func textAndUnitsStayExactlyAsTyped() throws {
        for text in ["500 μg", "500 mcg", "0.5 mg", "1 capsule", " 2 tabs ", "1/2 tablet", "10000 IU"] {
            #expect(try #require(Dose(text)).text == text)
        }
    }
}
