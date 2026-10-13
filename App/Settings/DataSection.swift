import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// "Your Data": the record export, the backup, and the restore (D040).
/// Maru sends nothing by itself. The user gives each file to an app in the share sheet.
struct DataSection: View {
    @Environment(AppModel.self) private var model
    @State private var picksBackup = false
    /// The failure on the display. It is a copy, so the alert keeps its text while it closes.
    @State private var shownFailure: DataTransferState.Failure?
    @State private var showsFailure = false

    var body: some View {
        @Bindable var model = model
        Section {
            Button("Export Records") { model.exportRecords() }
                .rowText()
                .sheet(item: $model.transfer.shared, onDismiss: { model.shareDidEnd() }) { file in
                    ShareSheet(url: file.url) { model.transfer.shared = nil }
                        .smallSheet()
                }
            Button("Back Up") { model.backUp() }
                .rowText()
                .alert(failureTitle, isPresented: $showsFailure, presenting: shownFailure) { _ in
                    Button("OK", role: .cancel) {}
                } message: { failure in
                    switch failure {
                    case .fileNotMade: Text("Maru couldn’t make the file. Try again.")
                    case .notABackup: Text("This file is not a Maru backup, or it is damaged. Your data did not change.")
                    case .newerBackup: Text("A newer version of Maru made this backup. Update Maru, then try again. Your data did not change.")
                    case .notRestored: Text("Maru couldn’t restore this backup. Your data did not change.")
                    case .restoredNotConfirmed: Text("Maru couldn’t confirm that your iPhone saved the restored data. If your data looks wrong later, restore the backup again.")
                    }
                }
                .onChange(of: model.transfer.failure) { _, failure in
                    guard let failure else { return }
                    shownFailure = failure
                    showsFailure = true
                    model.transfer.failure = nil
                }
            Button("Restore from Backup…") { picksBackup = true }
                .rowText()
                // Every file can be picked, so a backup with a changed name still restores. The check refuses each other file.
                .fileImporter(isPresented: $picksBackup, allowedContentTypes: [.data]) { result in
                    if case let .success(file) = result { model.checkBackup(at: file) }
                }
                // The one confirmation of a restore. Each button ends the wait of the checked backup.
                .alert(
                    "Replace Maru Data?",
                    isPresented: Binding(get: { model.transfer.staged != nil }, set: { _ in })
                ) {
                    Button("Replace", role: .destructive) { model.restore() }
                    Button("Cancel", role: .cancel) { model.cancelRestore() }
                } message: {
                    Text("This backup replaces all items and records in Maru. You can’t undo this.")
                }
        } header: {
            Text("Your Data")
        } footer: {
            Text("A backup moves your items, records, and some settings to a new iPhone, but not photos. The files are not encrypted, so share them only with people you trust.")
        }
        .disabled(model.transfer.isWorking)
    }

    private var failureTitle: Text {
        switch shownFailure {
        case .fileNotMade: Text("File Not Made")
        case .restoredNotConfirmed: Text("Restore Not Confirmed")
        default: Text("Not Restored")
        }
    }
}

/// The system share sheet for one file.
///
/// `ShareLink` needs the file before the tap and gives no sign when the sheet closes. The file holds health
/// data: Maru makes it after the tap and removes it when the sheet closes (spec 10). So this is the one
/// place that shows the share sheet of UIKit (D026).
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// The user shared the file or closed the sheet.
    let onEnd: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // The system calls this on the main thread. The sheet then closes in every case.
        controller.completionWithItemsHandler = { _, _, _, _ in
            MainActor.assumeIsolated { onEnd() }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
