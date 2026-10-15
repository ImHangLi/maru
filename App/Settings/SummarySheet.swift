import MaruCore
import SwiftUI

/// What the user chose in the summary sheet (D091).
struct SummaryRequest: Equatable {
    let days: Int
    let excluded: Set<ItemID>
}

/// The choice of a summary for a doctor: the period, and the items in it (D091). One item that the user does not want to
/// share does not force the user to share all of them. The sheet makes no file: it hands its choice to Settings.
struct SummarySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Called with the choice when the user taps Share. The sheet closes after it.
    let onShare: (SummaryRequest) -> Void
    @State private var days = 30
    @State private var excluded: Set<ItemID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Period", selection: $days) {
                        Text("Last 7 Days").tag(7)
                        Text("Last 30 Days").tag(30)
                        Text("Last 90 Days").tag(90)
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                } footer: {
                    Text("A summary has the number of doses that you took, skipped, and did not record. It stays on this iPhone until you share it.")
                }
                if case let .loaded(snapshot) = model.content, !(snapshot.list + snapshot.archived).isEmpty {
                    Section("Items") {
                        ForEach(snapshot.list + snapshot.archived) { entry in
                            Toggle(isOn: Binding(
                                get: { !excluded.contains(entry.id) },
                                set: { isIncluded in
                                    if isIncluded { excluded.remove(entry.id) } else { excluded.insert(entry.id) }
                                }
                            )) {
                                Text(verbatim: entry.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        onShare(SummaryRequest(days: days, excluded: excluded))
                        dismiss()
                    }
                }
            }
        }
    }
}
