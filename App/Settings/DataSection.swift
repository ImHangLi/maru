import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The page "Your Data" (D135).
struct DataPage: View {
    var body: some View {
        Form {
            DataSection()
        }
        .navigationTitle("Your Data")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The record export, the reports, the backup, and the restore (D040).
/// Maru sends nothing by itself. The user gives each file to an app in the share sheet.
private struct DataSection: View {
    @Environment(AppModel.self) private var model
    @State private var picksBackup = false
    /// The failure on the display. It is a copy, so the alert keeps its text while it closes.
    @State private var shownFailure: DataTransferState.Failure?
    @State private var showsFailure = false
    /// The summary sheet, and the choice that it made. The report starts after the sheet closes, so the share sheet
    /// never opens over it (D091).
    @State private var showsSummary = false
    @State private var summaryRequest: SummaryRequest?

    var body: some View {
        @Bindable var model = model
        Section {
            Button("Export Records") { model.exportRecords() }
                .rowText()
                .sheet(item: $model.transfer.shared, onDismiss: { model.shareDidEnd() }) { file in
                    ShareSheet(url: file.url) { model.transfer.shared = nil }
                        .smallSheet()
                }
            // With a second active member, one list for everyone or for one member (D129).
            if model.hasFamily {
                Menu {
                    Button("Everyone") { model.shareMedicationList(for: nil) }
                    ForEach(model.activePeople, id: \.id) { person in
                        Button {
                            model.shareMedicationList(for: person)
                        } label: {
                            Text(verbatim: person.displayName)
                        }
                    }
                } label: {
                    ProRowTitle("Share Medication List…").rowText()
                }
            } else {
                Button { model.shareMedicationList(for: nil) } label: { ProRowTitle("Share Medication List") }
                    .rowText()
            }
            // The sheet is free to open. Only the share of the PDF needs Maru Pro (D130).
            Button { showsSummary = true } label: { ProRowTitle("Share Summary…") }
                .rowText()
                .sheet(isPresented: $showsSummary, onDismiss: {
                    guard let request = summaryRequest else { return }
                    summaryRequest = nil
                    model.shareSummary(days: request.days, excluding: request.excluded, member: request.member)
                }) {
                    SummarySheet { summaryRequest = $0 }
                }
            Button("Back Up") { model.backUp() }
                .rowText()
                .alert(failureTitle, isPresented: $showsFailure, presenting: shownFailure) { _ in
                    Button("OK", role: .cancel) {}
                } message: { failure in
                    switch failure {
                    case .fileNotMade: Text("Couldn’t make the file. Try again.")
                    case .notABackup: Text("This isn’t a Maru backup, or the file is damaged. Nothing changed.")
                    case .newerBackup: Text("A newer Maru made this backup. Update Maru, then try again. Nothing changed.")
                    case .notRestored: Text("Couldn’t restore this backup. Nothing changed.")
                    case .restoredNotConfirmed: Text("Couldn’t confirm the restore. If anything looks wrong later, restore the backup again.")
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
                    Text("This replaces everything in Maru with the backup. You can’t undo it.")
                }
        } footer: {
            Text("A backup has your items and records, but not photos. The file isn’t encrypted, so keep it private.")
        }
        .disabled(model.transfer.isWorking)
    }

    private var failureTitle: Text {
        switch shownFailure {
        case .fileNotMade: Text("Couldn’t Make the File")
        case .restoredNotConfirmed: Text("Couldn’t Confirm the Restore")
        default: Text("Couldn’t Restore")
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
