import AVFoundation
import MaruCore
import MaruDatabase
import SwiftUI
import VisionKit

/// The one edit screen for a new or a stored item (spec 3 P03, docs/design.md "Add and edit").
///
/// The first view is short (D085): name and type, the plan with its times and repeat days, and the reminders
/// ("Alarm" and "Remind Again"). One row, "More Options", opens a page with the optional details: amount, the look of
/// the item (form, color, and photo), and note. The plan line under the times states the whole plan.
/// A new item has "Scan Label" above the name, and the name field proposes names from the built-in lists (D038).
/// Both only propose: the user sees each value here before the save. A known supplement name gives candidates
/// for the amount, the time, and the note, and it sets the usual form until the user chooses one (D043).
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
    @Environment(\.openURL) private var openURL
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @FocusState private var nameIsFocused: Bool
    /// The built-in name lists. They load when this screen opens, not at launch (spec 9).
    @State private var names: NameIndex?
    /// The names to propose under the name field while the user types.
    @State private var suggestions: [String] = []
    @State private var scansLabel = false
    @State private var scanFailed = false
    @State private var cameraIsOff = false
    /// The form words of the last label scan. They give the form until the user chooses one (D043).
    @State private var scannedForms: Set<LabelForm> = []
    /// The smart completion of the name (D043). `nil` for a medication or a name that the list does not have.
    @State private var completion: SmartCompletion?
    /// The user chose a form on this screen, so the app changes it no more. A stored item, a replacement,
    /// and a kept draft start with a chosen form.
    @State private var formIsChosen: Bool
    /// The photo that the user picked or removed on this screen (D056). It is not part of the draft file.
    @State private var photo = PhotoState()
    /// How the name got into the field, and whether a candidate of the smart completion filled a value. Only the
    /// kind goes to the usage statistics, never the name or the value (D077).
    @State private var nameSource = AnalyticsEvent.NameSource.typed
    @State private var usedCompletion = false
    /// The delay of the follow-ups. It stays while the user turns "Remind Again" off and on again on this screen.
    /// The interval that the user last chose in Settings, 30 minutes at first: the middle delay of D021, and the delay of Apple Health.
    @State private var followUpInterval: FollowUpInterval
    /// The system refused alarms at the first tap on the switch (D079).
    @State private var alarmsAreOff = false

    init(session: EditorSession) {
        self.session = session
        _followUpInterval = State(initialValue: session.start.followUp?.interval ?? session.context.newItemReminders.interval)
        _draft = State(initialValue: session.start)
        _showsRestored = State(initialValue: session.isRestored)
        _formIsChosen = State(initialValue: !session.isNew || session.replaced != nil || session.isRestored)
    }

    private var hasChanges: Bool { draft != session.original || photo.isChanged }
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
                if session.isNew, DataScannerViewController.isSupported {
                    scanSection
                }
                nameSection
                timesSection
                if !draft.times.isEmpty {
                    reminderSection
                }
                moreSection
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
            .sheet(isPresented: $scansLabel, onDismiss: scanClosed) {
                LabelScanView(use: use) {
                    scanFailed = true
                    scansLabel = false
                    model.scanDidFail()
                }
            }
            .alert(item: $saveError) { error in
                Alert(title: Text("Couldn’t Save"), message: Text(error.message))
            }
            .task { names = await NameList.index.value }
            .onChange(of: nameInput) {
                updateSuggestions()
                updateCompletion()
            }
            .onChange(of: formStep) {
                if case let .set(form) = formStep { draft.form = form }
            }
        }
        // The photo work belongs to the whole screen, not to one page of it, so a push to "More Options" and back
        // does not cancel it. When the screen closes, a late result writes nothing (T30).
        .photoWork($photo)
        // Only unsaved changes ask before the screen closes (spec 3 P03).
        .interactiveDismissDisabled(hasChanges)
        // Every close: Cancel, a swipe, a save, or a restore. The model ignores the close after a save.
        .onDisappear { model.editorDidClose(session, hadChanges: hasChanges) }
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
            draft.followUp != nil,
            draft.followUp?.count == .untilRecorded,
            draft.note == .custom,
            suggestions.count,
            proposedForm?.rawValue ?? "",
            candidates?.amounts.count ?? 0,
            candidates?.times.count ?? 0,
            candidates?.notes.count ?? 0,
            photo.isChanged,
            photo.step,
            photo.hasCutout,
        ]
    }

    /// What the name suggestions and the smart completion depend on.
    private var nameInput: [AnyHashable] {
        [draft.name, draft.category, nameIsFocused, names != nil]
    }

    /// The form of the scanned label, else the usual form of the supplement. The app sets it while the user did
    /// not choose a form. After that, and for a medication, it is a one-tap proposal (D038, D043).
    private var formStep: SmartCompletion.FormStep {
        SmartCompletion.formStep(
            usual: completion?.form,
            scanned: LabelText.proposedForm(from: scannedForms),
            current: draft.form,
            mayChange: !formIsChosen && draft.category == .supplement
        )
    }

    private var proposedForm: ItemForm? {
        if case let .propose(form) = formStep { form } else { nil }
    }

    /// The amounts, times, and note that the draft does not have yet.
    private var candidates: SmartCompletion? {
        completion?.open(
            amount: draft.amount,
            times: draft.times.compactMap { try? WallClockTime(hour: $0.hour, minute: $0.minute) },
            hasNote: draft.note != .none
        )
    }

    // MARK: Sections

    private var restoredSection: some View {
        Section {
            Label("Picked up where you left off.", systemImage: "clock.arrow.circlepath")
            Button("Start Over", role: .destructive) {
                DraftFile.remove(key: session.draftKey)
                draft = session.original
                showsRestored = false
            }
        }
    }

    /// The shortcut is the first thing on the screen of a new item. The camera permission comes with
    /// the first tap (spec 2.2).
    private var scanSection: some View {
        Section {
            Button(action: startScan) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Scan Label")
                                .fontWeight(.semibold)
                                .rowText()
                            Image(systemName: "sparkles")
                                .imageScale(.small)
                                .accessibilityHidden(true)
                        }
                        Text("Point the camera at the bottle.")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                } icon: {
                    Image(systemName: "camera.viewfinder")
                }
            }
            .alert("Camera Is Off", isPresented: $cameraIsOff) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To scan a label, allow the camera for Maru in Settings.")
            }
        }
    }

    private var nameSection: some View {
        Section {
            TextField("Name", text: $draft.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameIsFocused)
            // A proposal fills only the name. The user can ignore it and type any name.
            ForEach(suggestions, id: \.self) { name in
                Button(name) {
                    draft.name = name
                    nameSource = .suggestion
                    nameIsFocused = false
                }
                // A proposal has the app tint, so it reads as a suggestion and not as typed text (D082).
                .foregroundStyle(.tint)
                .accessibilityHint(Text("Fills the name."))
            }
            Picker("Type", selection: $draft.category) {
                Text("Supplement").tag(ItemCategory.supplement)
                Text("Medication").tag(ItemCategory.medication)
            }
            .pickerStyle(.segmented)
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
                .labelStyle(RowLabelStyle())
            if let parts = candidates?.times, !parts.isEmpty {
                CandidateRow(candidates: parts) { part in
                    Text(part.title)
                } hint: { part in
                    let time = part.time(confirmed: session.context.supplementTimes)
                    return Text("Adds a reminder time at \(SchedulePreview.format(hour: time.hour, minute: time.minute)).")
                } choose: { part in
                    let time = part.time(confirmed: session.context.supplementTimes)
                    draft.times.append(ItemDraft.Time(id: UUID(), hour: time.hour, minute: time.minute))
                    draft.times = draft.sortedTimes
                    usedCompletion = true
                }
            }
            if !draft.times.isEmpty {
                NavigationLink {
                    RepeatList(
                        weekdays: $draft.weekdays,
                        cycle: $draft.cycle,
                        today: { draft.today(keptZoneFrom: session.zoneSchedule) }
                    )
                } label: {
                    LabeledContent {
                        Text(SchedulePreview.days(of: draft))
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
            Text("Plan")
        } footer: {
            timesFooter
        }
    }

    /// The plan line. With no time it says that there is no reminder.
    private var timesFooter: some View {
        let preview = SchedulePreview.text(
            for: draft, problem: problem, otherZone: otherZone, today: draft.today(keptZoneFrom: session.zoneSchedule)
        )
        return Text(preview)
            .accessibilityLabel(Text("Plan: \(preview)"))
    }

    /// "Alarm" and "Remind Again" belong to the item (D079). Each item has its own value, and a new item starts with
    /// the value that the user last chose in Settings (D085).
    private var reminderSection: some View {
        Section {
            if #available(iOS 26, *) { alarmRow }
            Picker("Remind Again", selection: followUpCount) {
                Text("Off").tag(FollowUpCount?.none)
                ForEach(FollowUpCount.allCases, id: \.self) { count in
                    Text(count.title).tag(FollowUpCount?.some(count))
                }
            }
            .tint(Color.primary)
            if draft.followUp != nil {
                Picker("Every", selection: followUpDelay) {
                    ForEach(FollowUpInterval.allCases, id: \.self) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .tint(Color.primary)
            }
        } header: {
            Text("Reminders")
        } footer: {
            // The one limit that matters: iPhone has no reminder that repeats with no end (D039).
            if draft.followUp?.count == .untilRecorded { UntilRecordedLimitText() }
        }
    }

    /// The system asks at the first tap on the switch (D079).
    @available(iOS 26, *)
    private var alarmRow: some View {
        Toggle("Alarm", isOn: Binding(get: { draft.alarm == true }, set: turnAlarm))
            .alert("Alarms Are Off", isPresented: $alarmsAreOff) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To use an alarm, allow alarms for Maru in Settings.")
            }
    }

    /// One row that opens the optional details, so the first view stays short (D085). Its value shows what the
    /// page holds: the amount and the note.
    private var moreSection: some View {
        Section {
            NavigationLink {
                moreOptionsPage
            } label: {
                LabeledContent("More Options") {
                    Text(moreSummary)
                }
            }
        }
    }

    private var moreSummary: String {
        let note: String? = switch draft.note {
        case .none: nil
        case .withFood: String(localized: "With food")
        case .emptyStomach: String(localized: "On an empty stomach")
        case .custom: draft.noteText.allSatisfy(\.isWhitespace) ? nil : draft.noteText
        }
        let amount = draft.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        return [amount, note].compactMap { $0 }.filter { !$0.isEmpty }.formatted(.list(type: .and, width: .narrow))
    }

    /// The optional details: the amount, the look of the item, and the note. The photo work stays on the first page,
    /// so it runs while the user is on the page and after the user goes back (T30).
    private var moreOptionsPage: some View {
        Form {
            amountSection
            lookSection
            noteSection
        }
        .scrollDismissesKeyboard(.interactively)
        .motion(.layout, value: layout)
        .navigationTitle("More Options")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The icon of the item, the form, the color, and the photo, in one section (D073). System menus of the six
    /// forms (D013) and the eight item colors (D021). The value shows the icon or the color.
    private var lookSection: some View {
        LookSection(
            state: $photo,
            storedReference: session.context.item?.imageReference,
            form: draft.form,
            color: draft.color
        ) {
            Picker("Form", selection: chosenForm) {
                ForEach(ItemForm.allCases, id: \.self) { form in
                    Label { Text(form.title) } icon: { form.menuImage(in: appColor.tint) }
                        .tag(form)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.primary)
            if let form = proposedForm {
                Button(form.useTitle) {
                    draft.form = form
                    formIsChosen = true
                }
                .foregroundStyle(.tint)
            }
            Picker("Color", selection: $draft.color) {
                ForEach(ItemColor.allCases, id: \.self) { color in
                    Label { Text(color.title) } icon: { color.color.circleImage }
                        .tag(color)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.primary)
        }
    }

    private var amountSection: some View {
        Section {
            TextField("For example 1000 IU", text: $draft.amount)
            if let amounts = candidates?.amounts, !amounts.isEmpty {
                CandidateRow(candidates: amounts, title: { Text(verbatim: $0) }, hint: { _ in Text("Fills the amount.") }) {
                    draft.amount = $0
                    usedCompletion = true
                }
            }
        } header: {
            Text("Amount")
        } footer: {
            // The amount belongs to the reminder plan, so an item with no time saves no amount.
            if draft.times.isEmpty, Dose(draft.amount) != nil {
                Text("Add a time to save the amount.")
            }
        }
    }

    private var noteSection: some View {
        Section {
            Picker("Note", selection: $draft.note) {
                Text("None").tag(ItemDraft.Note.none)
                Text("With food").tag(ItemDraft.Note.withFood)
                Text("On an empty stomach").tag(ItemDraft.Note.emptyStomach)
                Text("My own note").tag(ItemDraft.Note.custom)
            }
            .tint(Color.primary)
            if draft.note == .custom {
                TextField("Your note", text: $draft.noteText, axis: .vertical)
            }
            if let notes = candidates?.notes, !notes.isEmpty {
                CandidateRow(candidates: notes, title: \.title, hint: { _ in Text("Sets the note.") }, choose: useNote)
            }
        } footer: {
            // One sentence under the last candidates says where they come from (D043).
            if let candidates, !candidates.hasNoCandidates {
                Text("Suggestions come from common labels, so check your own label.")
            }
        }
    }

    // MARK: Actions

    /// The count menu. The delay stays when the menu goes to "Off" and comes back (D039).
    private var followUpCount: Binding<FollowUpCount?> {
        Binding {
            draft.followUp?.count
        } set: { count in
            draft.followUp = count.map { FollowUpSetting(count: $0, interval: followUpInterval) }
        }
    }

    private var followUpDelay: Binding<FollowUpInterval> {
        Binding {
            followUpInterval
        } set: { interval in
            followUpInterval = interval
            if let count = draft.followUp?.count { draft.followUp = FollowUpSetting(count: count, interval: interval) }
        }
    }

    /// The switch turns on at once. If the user does not allow alarms, it turns off again with one sentence and a
    /// button to Settings (D079).
    private func turnAlarm(_ isOn: Bool) {
        draft.alarm = isOn ? true : nil
        guard isOn else { return }
        Task {
            guard await model.allowAlarms() else {
                draft.alarm = nil
                alarmsAreOff = true
                return
            }
        }
    }

    /// The form menu. A choice of the user stops the app from changing the form (D043).
    private var chosenForm: Binding<ItemForm> {
        Binding {
            draft.form
        } set: { form in
            draft.form = form
            formIsChosen = true
        }
    }

    private func useNote(_ note: IntakeNote) {
        usedCompletion = true
        switch note {
        case .preset(.withFood): draft.note = .withFood
        case .preset(.emptyStomach): draft.note = .emptyStomach
        case let .text(text):
            draft.note = .custom
            draft.noteText = text
        }
    }

    /// The completion follows the name when the user leaves the field or picks a name, so the form does not
    /// change at each key press. A medication loses the candidates at once. The values of the draft stay.
    private func updateCompletion() {
        guard draft.category == .supplement, let names else {
            completion = nil
            return
        }
        // While the user types, a candidate of the earlier name must not stay, for example after a change to a medication name.
        guard !nameIsFocused else {
            completion = nil
            return
        }
        let isNamedHere = session.isNew || draft.trimmedName != session.original.trimmedName
        completion = isNamedHere ? names.completion(for: draft.name, category: draft.category) : nil
    }

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

    private func updateSuggestions() {
        guard nameIsFocused, let names else {
            suggestions = []
            return
        }
        suggestions = names.matches(draft.name, category: draft.category, ownNames: session.context.itemNames)
    }

    /// Opens the scanner. The system asks for the camera at the first tap. A camera that is off gets one
    /// sentence and a button to Settings. A user who refuses at the question gets no second message.
    private func startScan() {
        nameIsFocused = false
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: break
            case .notDetermined:
                guard await AVCaptureDevice.requestAccess(for: .video) else {
                    model.editorStep(.scanBlocked, in: session)
                    return
                }
            default:
                cameraIsOff = true
                model.editorStep(.scanBlocked, in: session)
                return
            }
            if DataScannerViewController.isAvailable {
                scansLabel = true
                model.editorStep(.scanOpened, in: session)
            } else {
                cameraIsOff = true
                model.editorStep(.scanBlocked, in: session)
            }
        }
    }

    /// The name from the scan goes to the draft as text that the user can edit. The scan sets no amount and
    /// no time. Its form counts as described at `formStep`.
    private func use(_ scan: LabelScan) {
        draft.name = scan.name
        nameSource = .scan
        scannedForms = scan.forms
        model.editorStep(.scanUsed, in: session)
    }

    private func scanClosed() {
        guard scanFailed else { return }
        scanFailed = false
        cameraIsOff = true
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
                try await model.save(
                    draft, in: session, photo: photo.edit, nameSource: nameSource, usedCompletion: usedCompletion
                )
            } catch {
                saveError = SaveErrorText(error)
            }
        }
    }
}

/// Candidates of the smart completion as small bordered buttons in one row, or in a column when the row
/// does not fit (D043). Nothing fills until a tap.
private struct CandidateRow<Candidate: Hashable>: View {
    let candidates: [Candidate]
    let title: (Candidate) -> Text
    let hint: (Candidate) -> Text
    let choose: (Candidate) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttons }
            VStack(alignment: .leading, spacing: 8) { buttons }
        }
    }

    private var buttons: some View {
        ForEach(candidates, id: \.self) { candidate in
            Button { choose(candidate) } label: { title(candidate) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                // A capsule in the app tint, like the name proposals (D082).
                .accessibilityHint(hint(candidate))
        }
    }
}

private extension IntakeNote {
    /// The words of the note menu, or the text of a note.
    var title: Text {
        switch self {
        case .preset(.withFood): Text("With food")
        case .preset(.emptyStomach): Text("On an empty stomach")
        case let .text(text): Text(verbatim: text)
        }
    }
}

private extension ItemForm {
    /// The form proposal, for example "Use Softgel".
    var useTitle: LocalizedStringKey {
        switch self {
        case .capsule, .unknown: "Use Capsule"
        case .tablet: "Use Tablet"
        case .softgel: "Use Softgel"
        case .powder: "Use Powder"
        case .drop: "Use Drops"
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

/// The repeat rule as a system list with check marks, like the repeat days of an alarm in Clock.
///
/// The first section has "Every Day" and the three rules that count days: "Every Other Day" (D036),
/// "Every Few Days", and "Days On and Off" (D065). Under it are the seven days, or the numbers and the first day
/// of a rule that counts days. All seven days on means every day (spec 2.1: visible and the user can change it).
/// The app picks no number and no first day: each starts empty, and Save stays off until the user chooses.
///
/// A first-day choice stores the calendar date that it has at the tap. For every other day, the check mark is
/// on the day that has a dose by the start date of the draft, so a stored plan shows its rhythm, and no tap is
/// needed to keep it. The other two rules can start on any date, so their check mark is on only when the
/// start date is that day, and the date row shows the start date.
///
/// The page can stay open across midnight. So a tap reads the date again, and the page reads it again
/// each minute for the check marks.
private struct RepeatList: View {
    @Binding var weekdays: Set<Weekday>
    @Binding var cycle: ItemDraft.Cycle?
    /// Today in the zone of the plan, at the time of the call. `nil` when the device zone has no region name.
    let today: () -> LocalDate?

    /// The row of a first day has the check mark: the plan of the draft has a dose on the date (every other day),
    /// or it starts on the date (the other rules).
    private func isOn(_ date: LocalDate?) -> Bool {
        guard let date, let start = cycle?.start?.date else { return false }
        guard cycle?.kind == .everyOtherDay else { return date == start }
        return date >= start && date.days(since: start).isMultiple(of: 2)
    }

    /// Starts the plan today or tomorrow, by the date at the time of the tap, when the row has no check mark yet.
    /// A tap on the row with the check mark changes nothing.
    private func start(daysFromToday days: Int) {
        guard let date = today()?.adding(days: days), !isOn(date) else { return }
        cycle?.start = ItemDraft.Day(date)
    }

    /// Changes the rule. The numbers and the first day start empty again. A tap on the rule that is on changes nothing.
    private func choose(_ kind: ItemDraft.Cycle.Kind) {
        if cycle?.kind != kind { cycle = ItemDraft.Cycle(kind: kind) }
    }

    /// The days from one dose to the next of "Every Few Days". The draft keeps them as 1 day on and the other days off.
    private var interval: Binding<Int?> {
        Binding {
            cycle?.daysOff.map { $0 + 1 }
        } set: { days in
            cycle?.daysOff = days.map { $0 - 1 }
        }
    }

    /// The start date for the date row, as noon in UTC. With no start date the row shows today, and the draft
    /// gets a date only when the user picks one.
    private var startDate: Binding<Date> {
        Binding {
            (cycle?.start?.date ?? today())?.noon ?? .now
        } set: { date in
            let parts = SchedulePreview.utcCalendar.dateComponents([.year, .month, .day], from: date)
            guard let year = parts.year, let month = parts.month, let day = parts.day,
                  let picked = try? LocalDate(year: year, month: month, day: day) else { return }
            cycle?.start = ItemDraft.Day(picked)
        }
    }

    var body: some View {
        // Each minute gives a new body, so the check marks follow the date.
        TimelineView(.everyMinute) { _ in
            list
        }
        .navigationTitle("Repeat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var list: some View {
        List {
            Section {
                CheckRow(title: Text("Every Day"), isOn: cycle == nil && weekdays.count == Weekday.allCases.count) {
                    cycle = nil
                    weekdays = Set(Weekday.allCases)
                }
                CheckRow(title: Text("Every Other Day"), isOn: cycle?.kind == .everyOtherDay) { choose(.everyOtherDay) }
                CheckRow(title: Text("Every Few Days"), isOn: cycle?.kind == .interval) { choose(.interval) }
                CheckRow(title: Text("Days On and Off"), isOn: cycle?.kind == .pause) { choose(.pause) }
            }
            if let rule = cycle {
                if rule.kind != .everyOtherDay {
                    Section {
                        if rule.kind == .interval {
                            DayCountPicker(title: "Interval", selection: interval, values: ItemDraft.Cycle.intervals) {
                                Text("Every \($0) days")
                            }
                        } else {
                            DayCountPicker(
                                title: "Days On", selection: Binding(get: { cycle?.daysOn }, set: { cycle?.daysOn = $0 }),
                                values: DayCycle.dayCounts
                            ) { Text(verbatim: "\($0)") }
                            DayCountPicker(
                                title: "Days Off", selection: Binding(get: { cycle?.daysOff }, set: { cycle?.daysOff = $0 }),
                                values: DayCycle.dayCounts
                            ) { Text(verbatim: "\($0)") }
                        }
                    } footer: {
                        if rule.counts == nil {
                            Text("Choose the number of days.")
                        }
                    }
                }
                let date = today()
                Section {
                    CheckRow(title: Text("Starting Today"), isOn: isOn(date)) { start(daysFromToday: 0) }
                    CheckRow(title: Text("Starting Tomorrow"), isOn: isOn(date?.adding(days: 1))) {
                        start(daysFromToday: 1)
                    }
                    // Every other day has two possible rhythms, so it needs no date (D036).
                    if rule.kind != .everyOtherDay {
                        DatePicker("Another Date", selection: startDate, displayedComponents: .date)
                            // A plan date has no zone. The row shows it as a date in UTC.
                            .environment(\.timeZone, .gmt)
                    }
                } footer: {
                    if rule.start?.date == nil {
                        Text("Choose the first day.")
                    }
                }
            } else {
                Section {
                    ForEach(SchedulePreview.orderedWeekdays, id: \.self) { day in
                        let isOn = weekdays.contains(day)
                        CheckRow(title: Text(verbatim: Calendar.current.standaloneWeekdaySymbols[day.rawValue % 7]), isOn: isOn) {
                            if isOn { weekdays.remove(day) } else { weekdays.insert(day) }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // The sections under the rule and their footers come and go with the layout motion (D030).
        // A check mark changes with no motion, as in Clock.
        .motion(.layout, value: [cycle?.kind.rawValue ?? "", "\(cycle?.counts != nil)", "\(cycle?.start != nil)"])
    }
}

/// A menu of numbers of days with an empty first choice, so the app picks no number (spec 2.1).
private struct DayCountPicker<Label: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Int?
    let values: ClosedRange<Int>
    @ViewBuilder let label: (Int) -> Label

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Choose").tag(Int?.none)
            ForEach(Array(values), id: \.self) { value in
                label(value).tag(Int?.some(value))
            }
        }
        .tint(Color.primary)
    }
}

/// One row with a check mark at the end when it is on.
private struct CheckRow: View {
    let title: Text
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                title
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
        .smallSheet()
    }
}
