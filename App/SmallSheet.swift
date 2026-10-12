import SwiftUI

extension View {
    /// The one size rule for a small sheet: a time wheel, a short list of choices, or the share sheet (D058).
    /// It opens at medium height, and the user can drag it to the full height, for example at a large text size.
    /// The edit screen of an item and the settings are full sheets and keep the system size.
    func smallSheet() -> some View {
        presentationDetents([.medium, .large])
    }
}
