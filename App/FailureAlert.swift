import MaruDatabase
import SwiftUI

/// The words of the alert for a record or a correction that gave no success (D014, D058).
/// Today, the as-needed section, and the history use these words, so each page says the same thing.
extension TodayFailure.Kind {
    /// "Not Saved", or the title of the page whose state changed.
    func alertTitle(changed: LocalizedStringKey) -> Text {
        if case .changed = self { Text(changed) } else { Text("Not Saved") }
    }

    var alertMessage: Text {
        switch self {
        case .notSaved(.unavailable):
            Text("Unlock your iPhone, then try again.")
        case .notSaved(.diskFull):
            Text("Your iPhone is full. Free some storage, then try again.")
        case .notSaved:
            Text("This didn’t save. Please try again.")
        case .changed:
            Text("This item changed. Check it, then try again.")
        }
    }
}
