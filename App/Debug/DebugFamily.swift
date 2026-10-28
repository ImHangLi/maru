#if DEBUG
import MaruCore
import SwiftUI
import UIKit

// A design prototype of Family mode, in the style of Apple's own apps. Debug builds only.
// The members live in memory and own items by name. Nothing here reads or writes the database.
// The text is not product copy yet. It uses `String` and `Text(verbatim:)`, so it stays out of the String Catalog.
//
// Launch arguments:
// - `-MaruFamily YES`: Me, Mom, and Mochi (a cat). Without it, only Me, and the app looks as it does today.
// - `-MaruFamilyShow mom`: Today starts filtered to that member (`me`, `mom`, `mochi`).
// - `-MaruFamilyOpen family` or `add`: open Settings, then the Family page, or the add page on it.

/// One person or pet. "Me" has no stored name and shows the word "Me".
struct DebugMember: Identifiable, Hashable {
    enum Kind: Hashable { case person, pet }

    let id: String
    var name: String
    var kind: Kind
    /// The SF Symbol of a pet.
    var animal = "pawprint.fill"

    var isMe: Bool { id == "me" }

    /// The avatar of "Everyone" in the person menu. It is not a member.
    static let everyone = DebugMember(id: "everyone", name: "Everyone", kind: .person)
}

@MainActor @Observable
final class DebugFamily {
    static let shared = DebugFamily()

    static let animals: [(symbol: String, name: String)] = [
        ("dog.fill", "Dog"), ("cat.fill", "Cat"), ("bird.fill", "Bird"),
        ("rabbit.fill", "Rabbit"), ("fish.fill", "Fish"), ("pawprint.fill", "Other"),
    ]

    var members: [DebugMember]
    /// The member that Today shows. `nil` is "Everyone".
    var selection: DebugMember.ID?
    var showsAddFromToday = false
    var showsAddFromSettings = false
    var opensFamilyPage = false

    /// The owner of each sample item, by its name. Every other item belongs to Me.
    private let owners = ["Levothyroxine": "mom", "Atorvastatin": "mom", "Methimazole": "mochi", "Flea and Tick Drops": "mochi"]

    private init() {
        let defaults = UserDefaults.standard
        var members = [DebugMember(id: "me", name: "Me", kind: .person)]
        if defaults.bool(forKey: "MaruFamily") {
            members.append(DebugMember(id: "mom", name: "Mom", kind: .person))
            members.append(DebugMember(id: "mochi", name: "Mochi", kind: .pet, animal: "cat.fill"))
        }
        self.members = members
        selection = defaults.string(forKey: "MaruFamilyShow").flatMap { id in members.contains { $0.id == id } ? id : nil }
        let open = defaults.string(forKey: "MaruFamilyOpen")
        opensFamilyPage = open == "family" || open == "add"
        showsAddFromSettings = open == "add"
    }

    static var wantsSettings: Bool {
        UserDefaults.standard.string(forKey: "MaruFamilyOpen") != nil
    }

    /// The family shows only when a second member exists. With only Me, nothing on Today changes.
    var isOn: Bool { members.count > 1 }

    var selected: DebugMember? { members.first { $0.id == selection } }

    func owner(of name: String) -> DebugMember {
        let id = owners[name] ?? "me"
        return members.first { $0.id == id } ?? members[0]
    }

    /// Whether Today shows this item in the current view.
    func shows(_ name: String) -> Bool {
        guard isOn, let selection else { return true }
        return owner(of: name).id == selection
    }

    func itemCount(of member: DebugMember) -> Int {
        // The sample items of `DebugLaunch`. Methimazole loads only with the sample family.
        var names = ["Vitamin D3", "Levothyroxine", "Omega-3", "Magnesium Glycinate", "Atorvastatin", "Ibuprofen"]
        if UserDefaults.standard.bool(forKey: "MaruFamily") { names.append("Methimazole") }
        return names.filter { owner(of: $0).id == member.id }.count
    }

    func add(_ member: DebugMember) {
        members.append(member)
    }
}

// MARK: - Avatar

/// The avatar of a member, drawn as Apple draws a contact: a photo, else a flat gray circle with a white initial
/// (Contacts), or a white animal symbol for a pet. "Me" with no photo has the person silhouette. No gradient.
struct MemberAvatar: View {
    let member: DebugMember
    let side: CGFloat

    var body: some View {
        Circle()
            .fill(Color(.systemGray))
            .overlay {
                switch member.kind {
                case .pet:
                    Image(systemName: member.animal)
                        .font(.system(size: side * 0.48, weight: .medium))
                case .person where member.id == DebugMember.everyone.id:
                    Image(systemName: "person.2.fill")
                        .font(.system(size: side * 0.36, weight: .medium))
                case .person where member.isMe:
                    Image(systemName: "person.fill")
                        .font(.system(size: side * 0.5, weight: .medium))
                        .offset(y: side * 0.02)
                case .person:
                    Text(verbatim: initial)
                        .font(.system(size: side * 0.46, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }

    private var initial: String {
        member.name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }
}

extension MemberAvatar {
    /// The avatar as an image for a system menu, which draws only images.
    @MainActor static func image(_ member: DebugMember, side: CGFloat = 24) -> Image {
        let renderer = ImageRenderer(content: MemberAvatar(member: member, side: side))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return Image(systemName: "person.crop.circle") }
        return Image(uiImage: image.withRenderingMode(.alwaysOriginal))
    }
}

// MARK: - Today

/// The title of Today: "Today" for everyone, or the name of the one member that it shows, as Health titles the data
/// of a person who shares with you.
struct DebugFamilyTitle: ViewModifier {
    @State private var family = DebugFamily.shared

    func body(content: Content) -> some View {
        // One modifier for both titles, so the large title keeps its place when the view changes.
        content.navigationTitle(family.selected.map { Text(verbatim: $0.name) } ?? Text("Today"))
    }
}

/// The person menu of Today: the avatar of the shown member at the top right, as the profile picture of Health.
/// A tap opens a system menu with "Everyone", each member, and "Add Person or Pet". It shows only with a second member.
struct DebugFamilyMenu: ToolbarContent {
    @State private var family = DebugFamily.shared

    var body: some ToolbarContent {
        if family.isOn {
            if #available(iOS 26, *) {
                ToolbarSpacer(.fixed, placement: .primaryAction)
                ToolbarItem(placement: .primaryAction) { menu }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .primaryAction) { menu }
            }
        }
    }

    private var menu: some View {
        Menu {
            Picker(selection: Binding(get: { family.selection }, set: { new in
                withMotion(.layout) { family.selection = new }
            })) {
                Label {
                    Text(verbatim: "Everyone")
                } icon: {
                    MemberAvatar.image(.everyone)
                }
                .tag(DebugMember.ID?.none)
                ForEach(family.members) { member in
                    Label {
                        Text(verbatim: member.name)
                    } icon: {
                        MemberAvatar.image(member)
                    }
                    .tag(DebugMember.ID?.some(member.id))
                }
            } label: {
                Text(verbatim: "Show")
            }
            .pickerStyle(.inline)
            Section {
                Button {
                    family.showsAddFromToday = true
                } label: {
                    Label {
                        Text(verbatim: "Add Person or Pet")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
        } label: {
            MemberAvatar(member: family.selected ?? .everyone, side: 36)
                .accessibilityHidden(false)
                .accessibilityLabel(Text(verbatim: "Showing \(family.selected?.name ?? "Everyone")"))
        }
        .sheet(isPresented: $family.showsAddFromToday) { DebugAddMemberView() }
    }
}

/// The owner of a row in "Everyone": a small avatar before the record circle, as Reminders shows the assignee
/// of a shared reminder. A row of Me has no avatar, as Messages draws no avatar beside your own messages.
/// A member view has no avatar, because every row has the same owner.
struct DebugRowOwner: View {
    let name: String
    @State private var family = DebugFamily.shared
    @ScaledMetric(relativeTo: .body) private var side = 24

    var body: some View {
        let owner = family.owner(of: name)
        if family.isOn && family.selection == nil && !owner.isMe {
            MemberAvatar(member: owner, side: min(side, 32))
        }
    }
}

// MARK: - Settings

/// The row "Family" in Settings, with the avatars of the members at its end, as the Family row of iOS Settings.
struct DebugFamilySection: View {
    @State private var family = DebugFamily.shared

    var body: some View {
        Section {
            NavigationLink(isActive: $family.opensFamilyPage) {
                DebugFamilyPage()
            } label: {
                LabeledContent {
                    if family.isOn {
                        AvatarStack(members: family.members)
                    }
                } label: {
                    Text(verbatim: "Family")
                }
            }
        }
    }
}

/// Overlapping avatars, each with a ring of the row color, as iOS Settings shows a family.
private struct AvatarStack: View {
    let members: [DebugMember]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(members) { member in
                MemberAvatar(member: member, side: 26)
                    .padding(1.5)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            }
        }
    }
}

/// The Family page: one row per member, as Family Sharing lists its members, and the row that adds one.
struct DebugFamilyPage: View {
    @State private var family = DebugFamily.shared

    var body: some View {
        List {
            // The first time, with only Me, the page says what Family does, as a page of iOS Settings does.
            if !family.isOn {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                            .padding(.bottom, 4)
                        Text(verbatim: "Family")
                            .font(.title2.bold())
                        Text(verbatim: "Keep doses and records for the people and pets you care for, each on their own.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            Section {
                ForEach(family.members) { member in
                    NavigationLink {
                        DebugAddMemberView(editing: member)
                    } label: {
                        HStack(spacing: 12) {
                            MemberAvatar(member: member, side: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: member.name)
                                Text(verbatim: itemLine(member))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Button {
                    family.showsAddFromSettings = true
                } label: {
                    Label {
                        Text(verbatim: "Add Person or Pet")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                .labelStyle(RowLabelStyle())
            } footer: {
                Text(verbatim: "Each one has their own items, reminders, and records. Nothing leaves this iPhone.")
            }
        }
        .navigationTitle(Text(verbatim: "Family"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $family.showsAddFromSettings) { DebugAddMemberView() }
    }

    private func itemLine(_ member: DebugMember) -> String {
        let count = family.itemCount(of: member)
        return count == 1 ? "1 item" : "\(count) items"
    }
}

// MARK: - Add or edit a member

/// The add page, as a new contact in Contacts: the avatar at the top with "Add Photo", then the name.
/// A pet gets an animal symbol in place of the initial.
struct DebugAddMemberView: View {
    var editing: DebugMember?
    @Environment(\.dismiss) private var dismiss
    @State private var family = DebugFamily.shared
    @State private var name = ""
    @State private var kind = DebugMember.Kind.person
    @State private var animal = "cat.fill"
    @FocusState private var nameFocused: Bool

    var body: some View {
        if editing == nil {
            NavigationStack { form }
        } else {
            form
        }
    }

    private var draft: DebugMember {
        DebugMember(id: editing?.id ?? UUID().uuidString, name: name, kind: kind, animal: animal)
    }

    private var form: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    MemberAvatar(member: draft, side: 112)
                        .motion(.state, value: draft)
                    Menu {
                        Button {} label: { Label { Text(verbatim: "Choose Photo") } icon: { Image(systemName: "photo.on.rectangle") } }
                        Button {} label: { Label { Text(verbatim: "Take Photo") } icon: { Image(systemName: "camera") } }
                    } label: {
                        Text(verbatim: "Add Photo")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    if editing?.isMe != true {
                        Picker(selection: $kind.animation(Motion.layout.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled))) {
                            Text(verbatim: "Person").tag(DebugMember.Kind.person)
                            Text(verbatim: "Pet").tag(DebugMember.Kind.pet)
                        } label: {
                            Text(verbatim: "Kind")
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .listRowBackground(Color.clear)
            }
            Section {
                TextField(text: $name, prompt: Text(verbatim: kind == .pet ? "Pet’s Name" : "Name")) {
                    Text(verbatim: "Name")
                }
                .focused($nameFocused)
                .textInputAutocapitalization(.words)
                if kind == .pet {
                    Picker(selection: $animal) {
                        ForEach(DebugFamily.animals, id: \.symbol) { animal in
                            Label {
                                Text(verbatim: animal.name)
                            } icon: {
                                Image(systemName: animal.symbol)
                            }
                            .tag(animal.symbol)
                        }
                    } label: {
                        Text(verbatim: "Animal")
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                }
            }
            if editing != nil && editing?.isMe != true {
                Section {
                    Button(role: .destructive) {} label: { Text(verbatim: "Archive \(name)…") }
                }
            }
        }
        .navigationTitle(Text(verbatim: editing == nil ? (kind == .pet ? "New Pet" : "New Person") : name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if editing == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        family.add(draft)
                        dismiss()
                    } label: {
                        Text(verbatim: "Add")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            // A new member starts at the name, as a new contact does.
            guard let editing else {
                nameFocused = true
                return
            }
            name = editing.name
            kind = editing.kind
            animal = editing.animal
        }
    }
}
#endif
