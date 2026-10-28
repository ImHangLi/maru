import MaruCore
import SwiftUI
import TipKit

/// One row: the form icon, the name with a second line under it, and the record circle. The second line has
/// the amount and the time that the user set, or the time of the record (D044).
///
/// Only the circle records. The name area is a separate area and never records (spec 3 P01).
/// A recorded row differs from an open row only by the circle and the time (D032, D044). It keeps its place,
/// so nothing moves under the finger (spec 4).
/// A swipe and a long press offer the same operations as the circle, plus the details and the edit screen.
/// They use the same record transaction, so the row changes only after the commit (spec 7.2, D028).
struct TodayRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let entry: TodaySnapshot.Entry
    let timeZone: TimeZone
    /// The first row of the day has the record tip on its circle (D103).
    var showsRecordTip = false
    @State private var showsCorrection = false
    @State private var showsTimeEditor = false

    var body: some View {
        let look = RecordLook(entry, model: model)
        HStack(spacing: 12) {
            // At the three largest text sizes the icon gives its width to the name (D013).
            if typeSize < .accessibility3 {
                FormIcon(form: entry.look.form, color: entry.look.color, photo: entry.look.imageReference)
                    .frame(minWidth: 32, minHeight: 44)
            }
            // The name area opens the details. It never records (spec 3 P01).
            NavigationLink(value: entry.look.itemID) {
                VStack(alignment: .leading, spacing: 2) {
                    // Names wrap and never truncate (spec 5.3).
                    Text(entry.look.name)
                        .foregroundStyle(.primary)
                    Text(verbatim: entry.detailText(in: timeZone))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .numberMotion(value: entry.detailText(in: timeZone))
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
                .accessibilityLabel(Text(verbatim: "\(entry.look.name), \(entry.detailText(in: timeZone))"))
                .accessibilityValue(entry.look.remindersOff ? Text("Reminders off") : Text(verbatim: ""))
            }
            // The record circle is the end of the row, so the row has no chevron.
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint(Text("Opens the details"))
            RecordButton(
                entry: entry,
                timeZone: timeZone,
                showsRecordTip: showsRecordTip,
                showsCorrection: $showsCorrection,
                showsTimeEditor: $showsTimeEditor
            )
        }
        // The row is 4 points lower than the list default, at the maintainer's request (D087). The touch areas keep 44 points.
        .padding(.vertical, -2)
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
            // An item action of the long press shows that the user knows it, so the tip of My Items does not come (D103).
            Button("Edit", systemImage: "pencil") {
                ItemMenuTip().invalidate(reason: .actionPerformed)
                model.openEditor(for: entry.look.itemID)
            }
            Button("Archive…", systemImage: "archivebox") {
                ItemMenuTip().invalidate(reason: .actionPerformed)
                model.askToEnd(.archive, itemID: entry.look.itemID, name: entry.look.name)
            }
            Button("Delete Item…", systemImage: "trash", role: .destructive) {
                ItemMenuTip().invalidate(reason: .actionPerformed)
                model.askToEnd(.delete, itemID: entry.look.itemID, name: entry.look.name)
            }
        }
    }

    /// An open row records it as taken now. A skipped row changes to taken.
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
    @Environment(\.tipsMayShow) private var tipsMayShow
    let entry: TodaySnapshot.Entry
    let timeZone: TimeZone
    let showsRecordTip: Bool
    /// The row owns these, so its context menu can open the same choices.
    @Binding var showsCorrection: Bool
    @Binding var showsTimeEditor: Bool

    var body: some View {
        let look = RecordLook(entry, model: model)
        Button {
            switch look {
            case .open:
                RecordTip().invalidate(reason: .actionPerformed)
                model.record(entry)
            case .notSaved: model.retry(entry)
            case .taken, .skipped: showsCorrection = true
            }
        } label: {
            RecordSymbol(state: look.symbolState)
        }
        .buttonStyle(.pressScale)
        // The tip waits while a sheet or an alert is on the display (D103).
        .popoverTip(RecordTip(), when: showsRecordTip && tipsMayShow)
        .confirmationDialog(dialogTitle, isPresented: $showsCorrection, titleVisibility: .visible) {
            if entry.record.status == .taken {
                Button("Change Time…") { showsTimeEditor = true }
                Button("Skip") { model.markSkipped(entry) }
            } else {
                Button("Taken") { model.markTaken(entry) }
            }
            Button("Undo", role: .destructive) { model.undo(entry) }
        }
        .sheet(isPresented: $showsTimeEditor) {
            ChangeTimeSheet(name: entry.look.name, time: entry.takenAt ?? .now) { model.changeTime(entry, to: $0) }
        }
        .accessibilityLabel(accessibilityLabel(look))
        .accessibilityValue(accessibilityState(look))
        .accessibilityHint(accessibilityHint(look))
    }

    private var dialogTitle: Text {
        if let takenAt = entry.takenAt { Text("Taken at \(takenAt.formatted(.rowTime(in: timeZone)))") } else { Text("Skipped") }
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
        case .taken: entry.takenAt.map { Text("Taken at \($0.formatted(.rowTime(in: timeZone)))") } ?? Text("Taken")
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
    enum State { case open, taken, skipped, notSaved }

    let state: State
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The scale of the circle while it fills (`Motion.fill`).
    @SwiftUI.State private var fillScale: CGFloat = 1

    var body: some View {
        // One image for every state, so the system replace effect runs between two states (D030).
        Image(systemName: name)
            .symbolRenderingMode(.palette)
            .foregroundStyle(mark, fill)
            .font(.title2)
            .scaleEffect(fillScale)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .symbolMotion(value: state)
            // The circle fills after the commit, so the spring starts there and never at the tap (spec 7.2).
            .onChange(of: state) { old, new in
                guard new == .taken, old != .taken, !reduceMotion else { return }
                fillScale = Motion.fillStartScale
                Task { @MainActor in withMotion(.fill) { fillScale = 1 } }
            }
            .accessibilityHidden(true)
    }

    private var name: String {
        switch state {
        case .open: "circle"
        case .taken: "checkmark.circle.fill"
        case .skipped: "minus.circle.fill"
        case .notSaved: "exclamationmark.circle"
        }
    }

    /// The first color of the symbol: the line of a ring, or the mark on a filled circle.
    private var mark: AnyShapeStyle {
        switch state {
        case .open: AnyShapeStyle(Color(.tertiaryLabel))
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
        case .open, .notSaved: mark
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
        .smallSheet()
    }
}

extension TodaySnapshot.Entry {
    /// The name and the amount. Two items with the same name differ by the amount (spec 5.3).
    var accessibilityNameText: String {
        amount.map { "\(look.name), \($0)" } ?? look.name
    }

    var takenAt: Date? {
        record.currentEvent.flatMap { $0.action == .taken ? $0.occurredAt : nil }
    }

    /// The second line of the row: the amount, then the time that the user set, or the record (D044).
    /// For example "2 capsules, 8:00 AM", "2 capsules, Taken at 8:07 AM", or "Skipped".
    func detailText(in timeZone: TimeZone) -> String {
        let state = switch record.status {
        case .unrecorded: plannedTimeText(in: timeZone)
        case .taken: takenAt.map { String(localized: "Taken at \($0.formatted(.rowTime(in: timeZone)))") }
            ?? String(localized: "Taken")
        case .skipped: String(localized: "Skipped")
        }
        return ([amount].compactMap(\.self) + [state]).detailLine
    }

    /// The time that the user set. A medication that keeps another time zone names the city of that zone,
    /// as the edit screen does (spec 8.5).
    private func plannedTimeText(in timeZone: TimeZone) -> String {
        let time = SchedulePreview.format(hour: occurrence.plannedTime.hour, minute: occurrence.plannedTime.minute)
        guard occurrence.timeZone.identifier != timeZone.identifier else { return time }
        return String(
            localized: "\(time) \(SchedulePreview.city(occurrence.timeZone)) time",
            comment: "Today: the reminder time of a medication that keeps another time zone. Example: 9:00 AM Shanghai time."
        )
    }
}

extension [String] {
    /// The parts of a detail line, such as an amount and a time. The parts are not a list of like things,
    /// so a list format joins them with "and" ("150 mg and 8:00 AM"), which is wrong. The amount is free text
    /// and can end with a space, so each part is trimmed before the separator.
    var detailLine: String {
        map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: String(localized: ", ", comment: "The separator between the parts of a detail line. Example: 2 capsules, 8:00 AM."))
    }
}
