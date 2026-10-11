import MaruCore
import MaruDatabase
import SwiftUI

/// The one edit screen for a new or a stored item (spec 3 P03, docs/design.md "Add and edit").
///
/// The order is name, type, form, color, amount, times, note. The plan line under the times states the whole plan.
/// Save is at the top right, as in every system sheet (D026). Apple Health needs seven screens for one
/// medication. Maru needs this one (D021).
struct ItemEditorView: View {
    let session: EditorSession

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft: ItemDraft
    @State private var isSaving = false
    @State private var confirmsDiscard = false
    @State private var saveError: SaveErrorText?
    /// The sheet where the user picks a time. It is not part of the draft until "Add" (spec 2.1).
    @State private var addsTime = false
    @State private var showsRestored: Bool

    init(session: EditorSession) {
        self.session = session
        _draft = State(initialValue: session.start)
        _showsRestored = State(initialValue: session.isRestored)
    }

    private var hasChanges: Bool { draft != session.original }
    private var problem: DraftProblem? {
        draft.problem(
            item: session.context.item,
            schedule: session.context.schedule,
            keptZoneFrom: session.zoneSchedule,
            now: .now,
            deviceTimeZone: NamedTimeZone(device: .current, at: .now)
        )
    }

    /// The zone that a medication keeps, only when the device is in another zone. The times on the screen
    /// are in that zone, so the screen names it (spec 8.5).
    private var otherZone: NamedTimeZone? {
        guard let zone = draft.keptTimeZone(from: session.zoneSchedule),
              zone != NamedTimeZone(device: .current, at: .now) else { return nil }
        return zone
    }

    var body: some View {
        NavigationStack {
            Form {
                if showsRestored {
                    restoredSection
                }
                nameSection
                formSection
                amountSection
                timesSection
                noteSection
            }
            .scrollDismissesKeyboard(.interactively)
            // A row or a footer that comes or goes moves the form (D030).
            .motion(.layout, value: layout)
            #if DEBUG
            .modifier(DebugDataBanner())
            #endif
            .navigationTitle(session.replaced != nil ? "New Product" : session.isNew ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .confirmationDialog("Discard your changes?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                            Button("Discard Changes", role: .destructive) { model.discardEditor() }
                            Button("Keep Editing", role: .cancel) {}
                        }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(problem != nil || isSaving)
                }
            }
            .sheet(isPresented: $addsTime) {
                NewTimeSheet(time: startOfNewTime, add: addTime)
            }
            .alert(item: $saveError) { error in
                Alert(title: Text("Maru couldn’t save"), message: Text(error.message))
            }
        }
        // Only unsaved changes ask before the screen closes (spec 3 P03).
        .interactiveDismissDisabled(hasChanges)
        .onChange(of: scenePhase) { _, phase in
            // The app can stop in the background. The draft comes back at the next open (spec 3 P03).
            guard phase != .active else { return }
            if hasChanges { DraftFile.save(draft, key: session.draftKey) } else { DraftFile.remove(key: session.draftKey) }
        }
        .onChange(of: draft) {
            // A draft that returns to the stored values is no longer a draft to keep.
            if !hasChanges { DraftFile.remove(key: session.draftKey) }
        }
    }

    /// What gives the form its layout: the rows and the footers that depend on the draft. The text that the
    /// user types is not in it.
    private var layout: [AnyHashable] {
        [
            showsRestored,
            draft.times.map(\.id),
            Dose(draft.amount) != nil,
            canRemoveTime,
            draft.note == .custom,
        ]
    }

    // MARK: Sections

    private var restoredSection: some View {
        Section {
            Label("Maru kept your unsaved changes.", systemImage: "clock.arrow.circlepath")
            Button("Start Over", role: .destructive) {
                DraftFile.remove(key: session.draftKey)
                draft = session.original
                showsRestored = false
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
            Picker("Type", selection: $draft.category) {
                Text("Supplement").tag(ItemCategory.supplement)
                Text("Medication").tag(ItemCategory.medication)
            }
            .pickerStyle(.segmented)
        }
    }

    /// System menus of the six forms (D013) and the eight item colors (D021). The value shows the icon or the color.
    private var formSection: some View {
        Section {
            Picker("Form", selection: $draft.form) {
                ForEach(ItemForm.allCases, id: \.self) { form in
                    Label { Text(form.title) } icon: { form.image }
                        .tag(form)
                }
            }
            .pickerStyle(.menu)
            Picker("Color", selection: $draft.color) {
                ForEach(ItemColor.allCases, id: \.self) { color in
                    Label { Text(color.title) } icon: { color.color.circleImage }
                        .tag(color)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var amountSection: some View {
        Section {
            TextField("For example 1000 IU", text: $draft.amount)
        } header: {
            Text("Amount (Optional)")
        } footer: {
            // The amount belongs to the reminder plan, so an item with no time saves no amount.
            if draft.times.isEmpty, Dose(draft.amount) != nil {
                Text("Add a time to save the amount.")
            }
        }
    }

    private var timesSection: some View {
        Section {
            ForEach($draft.times) { $time in
                TimeRow(time: $time, city: otherZone.map(SchedulePreview.city), canRemove: canRemoveTime) {
                    draft.times.removeAll { $0.id == time.id }
                }
            }
            Button("Add a Time", systemImage: "plus") { addsTime = true }
            if !draft.times.isEmpty {
                NavigationLink {
                    WeekdayList(weekdays: $draft.weekdays)
                } label: {
                    LabeledContent {
                        Text(SchedulePreview.days(draft.weekdays))
                    } label: {
                        if let city = otherZone.map(SchedulePreview.city) {
                            Text("Repeat (\(city) Time)")
                        } else {
                            Text("Repeat")
                        }
                    }
                }
            }
        } header: {
            Text("Reminder")
        } footer: {
            timesFooter
        }
    }

    /// The plan line. With no time it says that there is no reminder.
    private var timesFooter: some View {
        let preview = SchedulePreview.text(for: draft, problem: problem, otherZone: otherZone)
        return Text(preview)
            .accessibilityLabel(Text("Plan: \(preview)"))
    }

    private var noteSection: some View {
        Section {
            Picker("Note", selection: $draft.note) {
                Text("None").tag(ItemDraft.Note.none)
                Text("With food").tag(ItemDraft.Note.withFood)
                Text("On an empty stomach").tag(ItemDraft.Note.emptyStomach)
                Text("My own note").tag(ItemDraft.Note.custom)
            }
            if draft.note == .custom {
                TextField("Your note", text: $draft.noteText, axis: .vertical)
            }
        }
    }

    // MARK: Actions

    /// A stored plan keeps at least one time. The store keeps every version, and the end of a stored plan
    /// belongs to the item detail (issue #9).
    private var canRemoveTime: Bool {
        session.context.schedule == nil || draft.times.count > 1
    }

    /// The wheel starts at the next full hour. The first time of a supplement starts at the example time:
    /// a time that the user already confirmed for a supplement, else 08:00 (spec 2.1).
    /// The time counts only after the user taps "Add", so the draft has no default time (D032).
    private var startOfNewTime: Date {
        if draft.category == .supplement, draft.times.isEmpty, session.context.schedule == nil {
            let time = session.context.exampleTime
            return SchedulePreview.timeDate(hour: time.hour, minute: time.minute)
        }
        let hour = (Calendar.current.component(.hour, from: .now) + 1) % 24
        return SchedulePreview.timeDate(hour: hour, minute: 0)
    }

    private func hour(_ date: Date) -> Int { SchedulePreview.utcCalendar.component(.hour, from: date) }
    private func minute(_ date: Date) -> Int { SchedulePreview.utcCalendar.component(.minute, from: date) }

    private func addTime(_ date: Date) {
        draft.times.append(ItemDraft.Time(id: UUID(), hour: hour(date), minute: minute(date)))
        draft.times = draft.sortedTimes
    }

    private func cancel() {
        if hasChanges { confirmsDiscard = true } else { model.discardEditor() }
    }

    private func save() {
        guard problem == nil, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await model.save(draft, in: session)
            } catch {
                saveError = SaveErrorText(error)
            }
        }
    }
}

/// The text of a failed save. The draft stays on the screen, so the user loses nothing.
private struct SaveErrorText: Identifiable {
    let id = UUID()
    let message: LocalizedStringKey

    init(_ error: any Error) {
        message = switch error {
        case StorageError.unavailable: "Unlock your iPhone, then try again. Your entries are still here."
        case StorageError.diskFull: "Your iPhone is full. Free some storage, then try again. Your entries are still here."
        default: "Try again. Your entries are still here."
        }
    }
}

/// One reminder time. A tap opens the system time picker.
private struct TimeRow: View {
    @Binding var time: ItemDraft.Time
    /// The city of the kept zone when it is not the zone of the device.
    let city: String?
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack {
            DatePicker(selection: date, displayedComponents: .hourAndMinute) {
                if let city {
                    Text("\(city) Time")
                } else {
                    Text("Time")
                }
            }
            .environment(\.timeZone, .gmt)
            if canRemove {
                Button("Remove", systemImage: "minus.circle.fill", role: .destructive, action: remove)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .buttonStyle(.borderless)
            }
        }
    }

    private var date: Binding<Date> {
        Binding {
            SchedulePreview.timeDate(hour: time.hour, minute: time.minute)
        } set: { date in
            let calendar = SchedulePreview.utcCalendar
            time.hour = calendar.component(.hour, from: date)
            time.minute = calendar.component(.minute, from: date)
        }
    }
}

/// The seven days as a system list with check marks, like the repeat days of an alarm in Clock.
/// All seven on means every day (spec 2.1: visible and the user can change it).
private struct WeekdayList: View {
    @Binding var weekdays: Set<Weekday>

    var body: some View {
        List {
            ForEach(SchedulePreview.orderedWeekdays, id: \.self) { day in
                let isOn = weekdays.contains(day)
                Button {
                    if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    HStack {
                        Text(Calendar.current.standaloneWeekdaySymbols[day.rawValue % 7])
                            .foregroundStyle(Color.primary)
                        Spacer()
                        if isOn {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The time picker for a new reminder time. The time counts only after "Add" (spec 2.1).
private struct NewTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var time: Date
    let add: (Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    // A time of day has no zone. The editor stores it as a time in UTC.
                    .environment(\.timeZone, .gmt)
            }
            .navigationTitle("Add a Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        add(time)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
