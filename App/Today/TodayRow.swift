import MaruCore
import SwiftUI

/// One row: the form icon, the name with the optional amount under it, and the record circle.
///
/// Only the circle records. The name area is a separate area and never records (spec 3 P01).
/// A recorded row differs from an open row only by the circle (D032). It keeps its place, so nothing moves
/// under the finger (spec 4).
/// A swipe and a long press offer the same operations as the circle, plus the details and the edit screen.
/// They use the same record transaction, so the row changes only after the commit (spec 7.2, D028).
struct TodayRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let entry: TodaySnapshot.Entry
    let timeZone: TimeZone
    @State private var showsCorrection = false
    @State private var showsTimeEditor = false

    var body: some View {
        let look = RecordLook(entry, model: model)
        HStack(spacing: 12) {
            // At the three largest text sizes the icon gives its width to the name (D013).
            if typeSize < .accessibility3 {
                FormIcon(form: entry.look.form, color: entry.look.color)
                    .frame(minWidth: 32, minHeight: 44)
            }
            // The name area opens the details. It never records (spec 3 P01).
            NavigationLink(value: entry.look.itemID) {
                VStack(alignment: .leading, spacing: 1) {
                    // Names wrap and never truncate (spec 5.3).
                    Text(entry.look.name)
                        .foregroundStyle(.primary)
                    if let amount = entry.amount {
                        Text(amount)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    // The reminders are off, and the row stays so the user can still record it (T07).
                    if entry.look.remindersOff {
                        RemindersOffLabel()
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                // Two VoiceOver stops, like the two touch areas: the name, then the record circle (spec 3 P01).
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.accessibilityName)
                .accessibilityValue(entry.look.remindersOff ? Text("Reminders off") : Text(verbatim: ""))
            }
            // The record circle is the end of the row, so the row has no chevron.
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint(Text("Opens the details"))
            RecordButton(
                entry: entry,
                timeZone: timeZone,
                showsCorrection: $showsCorrection,
                showsTimeEditor: $showsTimeEditor
            )
        }
        // The first action of each edge runs with a full swipe. Undo needs a tap on its button.
        .swipeActions(edge: .leading) {
            switch look {
            case .open, .skipped: takenButton(look).tint(appColor.tint)
            case .notSaved: retryButton.tint(appColor.tint)
            case .taken: EmptyView()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            switch look {
            case .open: skipButton.tint(.gray)
            case .taken, .skipped: undoButton.tint(.gray)
            case .notSaved: EmptyView()
            }
        }
        .contextMenu {
            switch look {
            case .open:
                takenButton(look)
                // The time sheet records the row as taken at the time that the user chooses (D033).
                Button("Taken Earlier…", systemImage: "clock.arrow.circlepath") { showsTimeEditor = true }
                skipButton
            case .taken:
                Button("Change Time…", systemImage: "clock") { showsTimeEditor = true }
                skipButton
                undoButton
            case .skipped:
                takenButton(look)
                undoButton
            case .notSaved:
                retryButton
            }
            Divider()
            Button("Details", systemImage: "info.circle") { model.today.path.append(entry.look.itemID) }
            Button("Edit", systemImage: "pencil") { model.openEditor(for: entry.look.itemID) }
            Button("Archive…", systemImage: "archivebox") {
                model.askToEnd(.archive, itemID: entry.look.itemID, name: entry.look.name)
            }
        }
    }

    /// An open row records it as taken now. A skipped row changes to taken, as "Mark as Taken" does.
    private func takenButton(_ look: RecordLook) -> some View {
        Button("Taken", systemImage: "checkmark") {
            if look == .open { model.record(entry) } else { model.markTaken(entry) }
        }
    }

    private var skipButton: some View {
        Button("Skip", systemImage: "minus.circle") { model.markSkipped(entry) }
    }

    private var undoButton: some View {
        Button("Undo", systemImage: "arrow.uturn.backward") { model.undo(entry) }
    }

    private var retryButton: some View {
        Button("Try Again", systemImage: "arrow.clockwise") { model.retry(entry) }
    }
}

/// The state that the record circle shows. An unsaved event comes first (D014).
fileprivate enum RecordLook {
    case open, taken, skipped, notSaved

    @MainActor init(_ entry: TodaySnapshot.Entry, model: AppModel) {
        if model.today.pending[entry.id] != nil {
            self = .notSaved
            return
        }
        self = switch entry.record.status {
        case .unrecorded: .open
        case .taken: .taken
        case .skipped: .skipped
        }
    }
}

/// The record circle, an SF Symbol in a button. An open circle records the item as taken. A recorded
/// circle opens the correction choices, so it is not a switch (spec 3 P01). The fill and the haptic come
/// after the commit (spec 7.2).
private struct RecordButton: View {
    @Environment(AppModel.self) private var model
    let entry: TodaySnapshot.Entry
    let timeZone: TimeZone
    /// The row owns these, so its context menu can open the same choices.
    @Binding var showsCorrection: Bool
    @Binding var showsTimeEditor: Bool

    var body: some View {
        let look = RecordLook(entry, model: model)
        Button {
            switch look {
            case .open: model.record(entry)
            case .notSaved: model.retry(entry)
            case .taken, .skipped: showsCorrection = true
            }
        } label: {
            RecordSymbol(state: look.symbolState)
        }
        .buttonStyle(.borderless)
        .confirmationDialog(dialogTitle, isPresented: $showsCorrection, titleVisibility: .visible) {
            if entry.record.status == .taken {
                Button("Change Time…") { showsTimeEditor = true }
                Button("Mark as Skipped") { model.markSkipped(entry) }
            } else {
                Button("Mark as Taken") { model.markTaken(entry) }
            }
            Button("Undo", role: .destructive) { model.undo(entry) }
        }
        .sheet(isPresented: $showsTimeEditor) {
            ChangeTimeSheet(name: entry.look.name, time: takenAt ?? .now) { model.changeTime(entry, to: $0) }
        }
        .accessibilityLabel(accessibilityLabel(look))
        .accessibilityValue(accessibilityState(look))
        .accessibilityHint(accessibilityHint(look))
    }

    private var takenAt: Date? {
        entry.record.currentEvent.flatMap { $0.action == .taken ? $0.occurredAt : nil }
    }

    private var time: Date.FormatStyle {
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = timeZone
        return style
    }

    private var dialogTitle: Text {
        if let takenAt { Text("Taken at \(takenAt.formatted(time))") } else { Text("Skipped") }
    }

    /// The action and the item, so the circle differs from the name area: "Record Vitamin D".
    private func accessibilityLabel(_ look: RecordLook) -> Text {
        let name = entry.accessibilityNameText
        return switch look {
        case .open: Text("Record \(name)")
        case .notSaved: Text("Save \(name) again")
        case .taken, .skipped: Text("Change \(name)")
        }
    }

    private func accessibilityState(_ look: RecordLook) -> Text {
        switch look {
        case .open: Text("Not recorded")
        case .taken: takenAt.map { Text("Taken at \($0.formatted(time))") } ?? Text("Taken")
        case .skipped: Text("Skipped")
        case .notSaved: Text("Not saved")
        }
    }

    private func accessibilityHint(_ look: RecordLook) -> Text {
        switch look {
        case .open: Text("Records it as taken.")
        case .notSaved: Text("Tries to save it again.")
        case .taken, .skipped: Text("Shows ways to change it.")
        }
    }
}

private extension RecordLook {
    var symbolState: RecordSymbol.State {
        switch self {
        case .open: .open
        case .taken: .taken
        case .skipped: .skipped
        case .notSaved: .notSaved
        }
    }
}

/// The state of a dose as one SF Symbol: an empty circle, a filled check, a gray dash, or a red mark.
/// Taken and skipped differ also without color (spec 5.3). Today, the as-needed section, and the
/// history use it. The label and the value of the button say the state, so VoiceOver reads no image name.
struct RecordSymbol: View {
    enum State { case open, noRecord, taken, skipped, notSaved }

    let state: State
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink

    var body: some View {
        // One image for every state, so the system replace effect runs between two states (D030).
        Image(systemName: name)
            .symbolRenderingMode(.palette)
            .foregroundStyle(mark, fill)
            .font(.title2)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .symbolMotion(value: state)
            .accessibilityHidden(true)
    }

    private var name: String {
        switch state {
        case .open: "circle"
        case .noRecord: "circle.dashed"
        case .taken: "checkmark.circle.fill"
        case .skipped: "minus.circle.fill"
        case .notSaved: "exclamationmark.circle"
        }
    }

    /// The first color of the symbol: the line of a ring, or the mark on a filled circle.
    private var mark: AnyShapeStyle {
        switch state {
        case .open, .noRecord: AnyShapeStyle(Color(.tertiaryLabel))
        // The check mark is white or black on the tint (D025).
        case .taken: AnyShapeStyle(appColor.labelOnTint)
        case .skipped: AnyShapeStyle(Color.secondary)
        case .notSaved: AnyShapeStyle(Color.red)
        }
    }

    /// The second color: the fill of a filled circle. A ring has one color.
    private var fill: AnyShapeStyle {
        switch state {
        case .taken: AnyShapeStyle(.tint)
        case .skipped: AnyShapeStyle(Color(.tertiarySystemFill))
        case .open, .noRecord, .notSaved: mark
        }
    }
}

/// The time of an intake: a new time for a taken record, or the time of a dose that the user took earlier.
/// The history keeps the earlier time (T20). The time wheel shows at once, so the user needs no tap to open
/// a picker (D033).
struct ChangeTimeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let name: String
    @State var time: Date
    /// A record cannot be in the future. Two days back covers a dose after midnight.
    var earliest = Date.now.addingTimeInterval(-2 * 24 * 60 * 60)
    /// The history passes the end of the day after the dose. A time after now is never allowed.
    var latest = Date.now
    let save: (Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Taken at") {
                    DatePicker(
                        "Taken at",
                        selection: $time,
                        in: min(earliest, latest, .now)...min(latest, .now),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(Text(verbatim: name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // The sheet can stay open for a time. A record is never in the future.
                        save(min(time, .now))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

extension TodaySnapshot.Entry {
    /// The name and the amount. Two items with the same name differ by the amount (spec 5.3).
    var accessibilityNameText: String {
        amount.map { "\(look.name), \($0)" } ?? look.name
    }

    var accessibilityName: Text { Text(verbatim: accessibilityNameText) }
}
