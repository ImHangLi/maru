import MaruCore
import PhotosUI
import SwiftUI

/// The row "Family" in Settings, with the avatars of the members at its end, as the Family row of iOS Settings (D121).
struct FamilySection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            NavigationLink {
                FamilyPage()
            } label: {
                LabeledContent("Family") {
                    if model.hasFamily {
                        AvatarStack(people: model.activePeople)
                    }
                }
            }
        }
    }
}

/// The Family page: one row per member, as Family Sharing lists its members, the row that adds one, and the archived members.
struct FamilyPage: View {
    @Environment(AppModel.self) private var model
    @State private var addsMember = false

    var body: some View {
        List {
            // With only "Me", the page first says what Family does, as a page of iOS Settings does.
            if !model.hasFamily {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                            .padding(.bottom, 4)
                            .accessibilityHidden(true)
                        Text("Family")
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Keep doses and records for the people and pets you care for, each on their own.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            Section {
                ForEach(model.activePeople, id: \.id) { person in
                    memberRow(person)
                }
                Button {
                    Task { if await model.mayAddMember() { addsMember = true } }
                } label: {
                    Label("Add Person or Pet", systemImage: "person.badge.plus")
                }
                .labelStyle(RowLabelStyle())
            } footer: {
                Text("Each one has their own items, reminders, and records. Nothing leaves this iPhone.")
            }
            let archived = model.people.filter(\.isArchived)
            if !archived.isEmpty {
                Section("Archived") {
                    ForEach(archived, id: \.id) { person in
                        memberRow(person)
                    }
                }
            }
        }
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .motion(.layout, value: model.people)
        .sheet(isPresented: $addsMember) { NewMemberSheet() }
    }

    private func memberRow(_ person: Person) -> some View {
        NavigationLink {
            MemberPage(id: person.id)
        } label: {
            HStack(spacing: 12) {
                MemberAvatar(person, side: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: person.displayName)
                    if !person.isArchived {
                        Text("\(model.itemCount(of: person.id)) items")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// "Add Person or Pet", as a new contact in Contacts: the avatar at the top with "Add Photo", the kind, then the name.
/// The color is the first free member color (D128). The page of the member changes it later.
struct NewMemberSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var fields = MemberFields()
    @State private var isSaving = false
    @State private var failed = false
    @State private var color = ItemColor.blue

    var body: some View {
        NavigationStack {
            MemberForm(fields: $fields, color: color)
                .navigationTitle(fields.kind == .pet ? "New Pet" : "New Person")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add", action: add)
                            .disabled(fields.trimmedName.isEmpty || fields.isReadingPhoto || isSaving)
                    }
                }
                .alert("Couldn’t Save", isPresented: $failed) {
                    Button("OK", role: .cancel) {}
                }
        }
        .interactiveDismissDisabled(!fields.trimmedName.isEmpty)
        .onAppear { color = model.newMemberColor }
    }

    private func add() {
        guard let person = try? Person(
            kind: fields.kind, name: fields.trimmedName, symbol: fields.kind == .pet ? fields.symbol : nil, color: color
        ) else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await model.addMember(person, photo: fields.newPhoto)
                dismiss()
            } catch FamilyError.needsPro {
                dismiss()
            } catch {
                failed = true
            }
        }
    }
}

/// The page of one member: the same fields as the add page, the color, and archive, restore, or delete (D121, D125, D128).
struct MemberPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let id: PersonID
    @State private var fields = MemberFields()
    @State private var color = ItemColor.blue
    @State private var start: (MemberFields, ItemColor)?
    @State private var isSaving = false
    @State private var failed = false
    @State private var asks: Ask?

    private enum Ask: Identifiable {
        case archive, delete
        var id: Self { self }
    }

    private var person: Person? { model.people.first { $0.id == id } }

    private var hasChanges: Bool {
        guard let start else { return false }
        return start.0 != fields || start.1 != color
    }

    var body: some View {
        if let person {
            MemberForm(fields: $fields, color: person.kind == .me ? nil : color, isMe: person.kind == .me) {
                if person.kind != .me {
                    Picker("Color", selection: $color) {
                        ForEach(ItemColor.allCases, id: \.self) { color in
                            Label { Text(color.title) } icon: { color.tint.circleImage }
                                .tag(color)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                }
            } end: {
                endSection(person)
            }
            .navigationTitle(Text(verbatim: person.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(person) }
                        .disabled(!hasChanges || (person.kind != .me && fields.trimmedName.isEmpty) || fields.isReadingPhoto || isSaving)
                }
            }
            .alert("Couldn’t Save", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            }
            .confirmationDialog(
                asks == .delete ? Text("Delete \(person.displayName) and Their Items?") : Text("Archive \(person.displayName) and Their Items?"),
                isPresented: Binding(get: { asks != nil }, set: { if !$0 { asks = nil } }),
                titleVisibility: .visible,
                presenting: asks
            ) { ask in
                switch ask {
                case .archive:
                    Button("Archive", role: .destructive) { run { try await model.archiveMember(id) } }
                case .delete:
                    Button("Delete", role: .destructive) {
                        run(closes: true) { try await model.deleteMember(id) }
                    }
                }
            } message: { ask in
                switch ask {
                case .archive: Text("Their reminders stop. History keeps their records.")
                case .delete: Text("Every record of their items goes too. You can’t undo this.")
                }
            }
            .onAppear {
                guard start == nil else { return }
                fields = MemberFields(person)
                color = person.color ?? model.newMemberColor
                start = (fields, color)
            }
        }
    }

    @ViewBuilder private func endSection(_ person: Person) -> some View {
        if person.isArchived {
            Section {
                Button("Restore") { run { try await model.restoreMember(id) } }
            }
        } else if model.activePeople.count > 1 {
            Section {
                Button("Archive…", role: .destructive) { asks = .archive }
            }
        }
        // "Me" stays. The last active member stays (D125).
        if person.kind != .me, person.isArchived || model.activePeople.count > 1 {
            Section {
                Button("Delete…", role: .destructive) { asks = .delete }
            }
        }
    }

    private func save(_ person: Person) {
        let name = fields.trimmedName
        // "Me" with no name shows the word "Me" again (D121).
        guard let changed = try? Person(
            id: person.id,
            kind: person.kind == .me ? .me : fields.kind,
            name: name.isEmpty && person.kind == .me ? nil : name,
            symbol: fields.kind == .pet && person.kind != .me ? fields.symbol : nil,
            color: person.kind == .me ? nil : color,
            imageReference: person.imageReference,
            archivedAt: person.archivedAt
        ) else { return }
        run {
            try await model.updateMember(changed, photo: fields.photoEdit)
            fields.didSave()
            start = (fields, color)
        }
    }

    private func run(closes: Bool = false, _ operation: @escaping () async throws -> Void) {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await operation()
                if closes { dismiss() }
            } catch {
                failed = true
            }
        }
    }
}

/// The values of the member form. The photo is not stored until the save (D124).
struct MemberFields: Equatable {
    var name = ""
    var kind = PersonKind.person
    var symbol = PetSymbol.cat
    /// The photo of the stored member, if it has one.
    var storedPhoto: String?
    var photoRemoved = false
    var newPhoto: PhotoImage?
    var isReadingPhoto = false
    var photoUnreadable = false

    init() {}

    init(_ person: Person) {
        name = person.name ?? ""
        kind = person.kind
        symbol = person.symbol ?? .cat
        storedPhoto = person.imageReference
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var hasPhoto: Bool { newPhoto != nil || (storedPhoto != nil && !photoRemoved) }

    var photoEdit: MemberPhotoEdit {
        if let newPhoto { .replaced(newPhoto) } else if photoRemoved { .removed } else { .unchanged }
    }

    mutating func didSave() {
        newPhoto = nil
        photoRemoved = false
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.kind == rhs.kind && lhs.symbol == rhs.symbol && lhs.storedPhoto == rhs.storedPhoto
            && lhs.photoRemoved == rhs.photoRemoved && lhs.newPhoto?.data == rhs.newPhoto?.data
            && lhs.isReadingPhoto == rhs.isReadingPhoto && lhs.photoUnreadable == rhs.photoUnreadable
    }
}

extension MemberForm where Extra == EmptyView, End == EmptyView {
    /// The add page: no color row and no end section. The name has the focus.
    init(fields: Binding<MemberFields>, color: ItemColor?) {
        self.init(fields: fields, color: color, isMe: false, extra: { EmptyView() }, end: { EmptyView() })
        focusesName = true
    }
}

/// The form of the add page and of the member page: the avatar with "Add Photo", the kind, the name, and the animal of a pet.
private struct MemberForm<Extra: View, End: View>: View {
    @Binding var fields: MemberFields
    /// The color of the avatar preview. `nil` uses the app color, as "Me" does.
    let color: ItemColor?
    let isMe: Bool
    var focusesName = false
    @ViewBuilder var extra: Extra
    @ViewBuilder var end: End

    @Environment(\.openURL) private var openURL
    @FocusState private var nameIsFocused: Bool
    @State private var pickerItem: PhotosPickerItem?
    @State private var showsLibrary = false
    @State private var takesPhoto = false
    @State private var cameraIsOff = false
    @State private var photoTask: Task<Void, Never>?

    init(
        fields: Binding<MemberFields>, color: ItemColor?, isMe: Bool,
        @ViewBuilder extra: () -> Extra, @ViewBuilder end: () -> End
    ) {
        _fields = fields
        self.color = color
        self.isMe = isMe
        self.extra = extra()
        self.end = end()
    }

    /// The member as the avatar draws it now. A person with no name yet shows the person silhouette, as a new contact does.
    private var preview: Person? {
        let isPet = fields.kind == .pet && !isMe
        let hasInitial = !isPet && !isMe && !fields.trimmedName.isEmpty
        return try? Person(
            kind: isPet ? .pet : hasInitial ? .person : .me,
            name: isPet || hasInitial ? fields.trimmedName.isEmpty ? "?" : fields.trimmedName : nil,
            symbol: isPet ? fields.symbol : nil,
            color: color,
            imageReference: fields.photoRemoved ? nil : fields.storedPhoto
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 14) {
                    if let preview {
                        MemberAvatar(preview, side: 112, preview: fields.newPhoto?.preview)
                    }
                    photoMenu
                    if !isMe {
                        Picker("Kind", selection: $fields.kind.animation()) {
                            Text("Person").tag(PersonKind.person)
                            Text("Pet").tag(PersonKind.pet)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(.top, 10)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .listRowBackground(Color.clear)
            } footer: {
                if fields.photoUnreadable {
                    Text("Maru couldn’t read this photo.")
                        .frame(maxWidth: .infinity)
                }
            }
            Section {
                TextField("Name", text: $fields.name, prompt: isMe ? Text(verbatim: DoseOwner.meName) : nil)
                    .focused($nameIsFocused)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                if fields.kind == .pet && !isMe {
                    Picker("Animal", selection: $fields.symbol) {
                        ForEach(PetSymbol.allCases, id: \.self) { symbol in
                            Label { Text(symbol.title) } icon: { Image(systemName: symbol.systemImage) }
                                .tag(symbol)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.primary)
                }
                extra
            }
            end
        }
        .photosPicker(isPresented: $showsLibrary, selection: $pickerItem, matching: .images)
        .fullScreenCover(isPresented: $takesPhoto) {
            CameraPicker { image in
                takesPhoto = false
                if let image { read(.camera(image)) }
            }
            .ignoresSafeArea()
        }
        .alert("Camera Is Off", isPresented: $cameraIsOff) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To take a photo, allow the camera for Maru in Settings.")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            read(.library(item))
        }
        .onAppear {
            // A new member starts at the name, as a new contact does.
            if focusesName { nameIsFocused = true }
        }
        .onDisappear { photoTask?.cancel() }
    }

    private var photoMenu: some View {
        Menu {
            Button("Choose Photo", systemImage: "photo.on.rectangle") { showsLibrary = true }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera") {
                    Task {
                        switch await CameraPicker.access() {
                        case true?: takesPhoto = true
                        case false?: cameraIsOff = true
                        case nil: break
                        }
                    }
                }
            }
            if fields.hasPhoto {
                Button("Remove Photo", systemImage: "trash", role: .destructive) {
                    photoTask?.cancel()
                    fields.newPhoto = nil
                    fields.isReadingPhoto = false
                    fields.photoRemoved = fields.storedPhoto != nil
                }
            }
        } label: {
            Group {
                if fields.isReadingPhoto {
                    ProgressView()
                } else if fields.hasPhoto {
                    Text("Edit Photo")
                } else {
                    Text("Add Photo")
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
    }

    /// The square crop of the photo, as an item photo is stored (D056). The avatar draws it in a circle.
    private func read(_ source: PhotoSource) {
        photoTask?.cancel()
        fields.isReadingPhoto = true
        fields.photoUnreadable = false
        photoTask = Task {
            let crop = await PhotoProcessor.crop(source)
            guard !Task.isCancelled else { return }
            fields.isReadingPhoto = false
            if let crop {
                fields.newPhoto = crop.image
            } else {
                fields.photoUnreadable = true
            }
        }
    }
}
