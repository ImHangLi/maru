import MaruDatabase
import SwiftUI

/// The plain state for a database that did not open or did not read (spec 7.3, T37).
///
/// It says what happened and that the data is still there. It shows no empty list, and it offers
/// no action that clears or rebuilds the database.
struct StorageProblemView: View {
    @Environment(AppModel.self) private var model
    let error: StorageError

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if model.canRetry {
                Button("Try Again") { model.refresh() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var title: LocalizedStringKey {
        switch error {
        case .corrupt, .migrationFailed: "Maru Can’t Open Your Data"
        case .newerSchema: "Update Maru to Open Your Data"
        case .diskFull: "Your iPhone Is Full"
        default: "Maru Can’t Read Your Data Right Now"
        }
    }

    private var message: LocalizedStringKey {
        switch error {
        case .corrupt:
            "Your data file is damaged. Maru left it exactly as it was."
        case .migrationFailed:
            "This version of Maru can’t open your data. It’s safe, and nothing changed."
        case .newerSchema:
            "A newer version of Maru saved your data. It’s safe, and nothing changed."
        case .diskFull:
            "Free some storage, then try again. Your data is safe."
        case .unavailable:
            "If your iPhone is locked, unlock it and try again. Your data is safe."
        default:
            "Your data is safe. Nothing changed."
        }
    }
}
