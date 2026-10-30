import MaruCore
import SwiftUI

/// The person menu of Today: the avatar of the shown member at the top right, as the profile picture of Health (D121).
/// A tap opens a system menu with "Everyone", each member, and "Add Person or Pet". It shows only with a second active member,
/// so with only "Me" Today looks as before (T57). It has the button style of Settings at the top left: its own bar button
/// with the system background, and the avatar inside it (D140).
struct PersonMenu: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        if model.hasFamily {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { PersonMenuButton() }
            } else {
                ToolbarItem(placement: .primaryAction) { PersonMenuButton() }
            }
        }
    }
}

private struct PersonMenuButton: View {
    @Environment(AppModel.self) private var model
    @State private var addsMember = false

    var body: some View {
        let shown = model.shownMember
        Menu {
            Picker(selection: Binding(
                get: { model.shownMember?.id },
                set: { id in withMotion(.layout) { model.show(member: id) } }
            )) {
                Label {
                    Text("Everyone")
                } icon: {
                    MemberAvatar.menuImage(.everyone)
                }
                .tag(PersonID?.none)
                ForEach(model.activePeople, id: \.id) { person in
                    Label {
                        Text(verbatim: person.displayName)
                    } icon: {
                        MemberAvatar.menuImage(.member(person))
                    }
                    .tag(PersonID?.some(person.id))
                }
            } label: {
                Text("Show")
            }
            .pickerStyle(.inline)
            Section {
                Button("Add Person or Pet", systemImage: "person.badge.plus") {
                    Task { if await model.mayAddMember() { addsMember = true } }
                }
            }
        } label: {
            Group {
                if let shown {
                    MemberAvatar(shown, side: 28)
                } else {
                    MemberAvatar(.everyone, side: 28)
                }
            }
        }
        .accessibilityLabel(Text("Show"))
        .accessibilityValue(shown.map { Text(verbatim: $0.displayName) } ?? Text("Everyone"))
        .sheet(isPresented: $addsMember) { NewMemberSheet() }
    }
}

/// The owner of a row in "Everyone": a small avatar before the record circle, as Reminders shows the assignee of a shared
/// reminder (D121). A row of "Me" has no avatar, as Messages draws no avatar beside your own messages. A view of one member has
/// no avatar, because every row has the same owner. A tile of My Items uses it too (D129).
struct RowOwner: View {
    @Environment(AppModel.self) private var model
    let personID: PersonID
    @ScaledMetric(relativeTo: .body) private var side = 24

    var body: some View {
        if let owner = model.rowOwner(of: personID) {
            MemberAvatar(owner, side: min(side, 32))
        }
    }
}

extension AppModel {
    /// The member that a row or a tile names in "Everyone": not "Me", and only with a second active member (D121, D129).
    func rowOwner(of personID: PersonID) -> Person? {
        guard hasFamily, shownMember == nil, let owner = activePeople.first(where: { $0.id == personID }), owner.kind != .me
        else { return nil }
        return owner
    }
}
