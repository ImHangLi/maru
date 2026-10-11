import Foundation
import Testing
@testable import MaruCore

@Suite("Dose is optional free text with no default (spec 2.1, 7.2)")
struct DoseTests {
    @Test func aScheduleVersionHasNoDoseUnlessTheUserGivesOne() throws {
        let (schedule, _, _) = Fixtures.twiceDailySchedule()
        #expect(try #require(schedule.versions.first).dose == nil)
    }

    @Test func textAndUnitsStayExactlyAsTyped() throws {
        for text in ["500 μg", "500 mcg", "0.5 mg", "1 capsule", " 2 tabs ", "1/2 tablet", "10000 IU"] {
            #expect(try #require(Dose(text)).text == text)
        }
    }

    @Test func differentUnitsAreDifferentDoses() throws {
        let pairs = [("1 mg", "1000 μg"), ("500 μg", "500 mcg"),
                     // U+00B5 (micro sign) and U+03BC (Greek mu) are not merged.
                     ("500 \u{00B5}g", "500 \u{03BC}g")]
        for (left, right) in pairs {
            let leftDose = try #require(Dose(left))
            let rightDose = try #require(Dose(right))
            #expect(leftDose != rightDose)
        }
    }
}
