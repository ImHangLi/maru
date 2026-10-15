import MaruCore
import SwiftUI

/// The archived items, from the entry at the end of My Items (spec 3 P02). Restore is one tap: the item comes
/// back to Today and My Items, and its reminders follow its own setting (T08). A swipe or a long press
/// deletes an item with its records, after one confirmation (D033).
struct ArchivedListView: View {
    @Environment(AppModel.self) private var model
    @State private var restoring: Set<ItemID> = []
    @State private var restoreFailed = false

    var body: some View {
        Group {
            if case let .loaded(snapshot) = model.content {
                List {
                    Section {
                        ForEach(snapshot.archived) { entry in
                            row(entry)
                        }
                    } footer: {
                        Text("Archived items keep their records but get no reminders.")
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if snapshot.archived.isEmpty {
                        ContentUnavailableView {
                            Label("No Archived Items", systemImage: "archivebox")
                        }
                    }
                }
                // A restored row leaves with the layout motion, and the empty text fades (D030).
                .motion(.layout, value: snapshot.archived.map(\.id))
            }
        }
        #if DEBUG
        .modifier(DebugDataBanner())
        #endif
        .navigationTitle("Archived")
        .alert("Not Changed", isPresented: $restoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Maru couldn’t save this change. Try again.")
        }
    }

    private func row(_ entry: ListEntry) -> some View {
        HStack(spacing: 12) {
            FormIcon(form: entry.form, color: entry.color, photo: entry.imageReference)
            // The name opens the item, with its counts and its full log (D091). Restore stays its own button.
            NavigationLink(value: entry.id) {
                Text(verbatim: entry.name)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint(Text("Shows its records"))
            Button("Restore") { restore(entry.id) }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(restoring.contains(entry.id))
                .accessibilityLabel(Text("Restore \(entry.name)"))
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { deleteButton(entry).tint(.red) }
        .contextMenu { deleteButton(entry) }
    }

    /// It has no destructive role: with that role the row leaves the list before the confirmation.
    private func deleteButton(_ entry: ListEntry) -> some View {
        Button("Delete Item…", systemImage: "trash") { model.askToEnd(.delete, itemID: entry.id, name: entry.name) }
    }

    private func restore(_ itemID: ItemID) {
        restoring.insert(itemID)
        Task {
            defer { restoring.remove(itemID) }
            do {
                try await model.setArchived(false, for: itemID)
            } catch {
                restoreFailed = true
            }
        }
    }
}
