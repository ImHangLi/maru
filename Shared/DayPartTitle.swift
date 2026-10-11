import MaruCore
import SwiftUI

/// The slot word, in the String Catalog of each target (D011, D048).
extension DayPart {
    var title: LocalizedStringResource {
        switch self {
        case .morning: "Morning"
        case .noon: "Noon"
        case .evening: "Evening"
        }
    }
}
