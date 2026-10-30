import MaruCore
import SwiftUI

/// What the user chose in the summary sheet (D091).
struct SummaryRequest: Equatable {
    let days: Int
    let excluded: Set<ItemID>
    /// The member of the summary, or `nil` for everyone (T65, D129).
    let member: PersonID?
}

/// The choice of a summary for a doctor: the period, and the items in it (D091). One item that the user does not want to
/// share does not force the user to share all of them. With a second active member, "For" makes a summary of one member, for
/// example for a vet (T65, D129). The sheet makes no file: it hands its choice to Settings.
struct SummarySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    /// Called with the choice when the user taps Share. The sheet closes after it.
    let onShare: (SummaryRequest) -> Void
    @State private var days = 30
    @State private var excluded: Set<ItemID> = []
    /// The member of the person menu when the sheet opens, else everyone.
    @State private var member: PersonID?
    @State private var didStart = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.hasFamily {
                        Picker("For", selection: $member) {
                            Label {
                                Text("Everyone")
                            } icon: {
                                MemberAvatar.menuImage(.everyone, gap: MemberAvatar.inlineGap)
                            }
                            .tag(PersonID?.none)
                            ForEach(model.activePeople, id: \.id) { person in
                                Label {
                                    Text(verbatim: person.displayName)
                                } icon: {
                                    MemberAvatar.menuImage(.member(person), gap: MemberAvatar.inlineGap)
                                }
                                .tag(PersonID?.some(person.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.primary)
                    }
                    Picker("Period", selection: $days) {
                        Text("Last 7 Days").tag(7)
                        Text("Last 30 Days").tag(30)
                        Text("Last 90 Days").tag(90)
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A summary has the number of doses that you took, skipped, and did not record. It stays on this iPhone until you share it.")
                        // The sheet stays open to every user, so a free user can see what a summary holds (D130).
                        if !model.pro.isPro {
                            Text("Sharing a PDF summary is part of Maru Pro.")
                        }
                    }
                }
                if case let .loaded(snapshot) = model.content,
                   case let entries = (snapshot.list + snapshot.archived).filter({ member == nil || $0.personID == member }),
                   !entries.isEmpty {
                    Section("Items") {
                        ForEach(entries) { entry in
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
            .onAppear {
                guard !didStart else { return }
                didStart = true
                member = model.shownMember?.id
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        onShare(SummaryRequest(days: days, excluded: excluded, member: member))
                        dismiss()
                    }
                }
            }
        }
    }
}
