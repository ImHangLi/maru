import MaruCore
import SwiftUI

/// The "As needed" section at the end of Today: the items with no active schedule (D021, docs/design.md).
/// Each item has a record button that records a dose now. The doses of today show under the item with
/// their time, and open the same correction choices as a recorded row.
struct AsNeededSection: View {
    @Environment(AppModel.self) private var model
    let rows: [AsNeededCard.Row]
    let timeZone: TimeZone

    var body: some View {
        Section {
            ForEach(rows) { row in
                AsNeededItemRow(row: row, timeZone: timeZone)
                ForEach(row.doses) { AsNeededDoseRow(row: row, dose: $0, timeZone: timeZone) }
            }
        } header: {
            Text("As Needed")
                .textCase(nil)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .alert(
            failureTitle,
            isPresented: Binding(
                get: { model.today.asNeeded.failure != nil },
                set: { if !$0 { model.today.asNeeded.failure = nil } }
            ),
            presenting: model.today.asNeeded.failure
        ) { failure in
            if case .notSaved = failure.kind {
                Button("Try Again") { model.retry(failure) }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { failure in
            failureMessage(failure.kind)
        }
    }

    private var failureTitle: Text {
        if case .changed = model.today.asNeeded.failure?.kind { Text("Today changed") } else { Text("Not saved") }
    }

    private func failureMessage(_ kind: AsNeededFailure.Kind) -> Text {
        switch kind {
        case .notSaved(.unavailable):
            Text("Unlock your iPhone, then try again.")
        case .notSaved(.diskFull):
            Text("Your iPhone is full. Free some storage, then try again.")
        case .notSaved:
            Text("Maru couldn’t save this. Try again.")
        case .changed:
            Text("This item changed. Check it, then try again.")
        }
    }
}

/// One item: the form icon, the name, and the record button. Like a row of a part of the day, the name area
/// never records (spec 3 P01). An as-needed item has no amount, because the amount belongs to a schedule.
/// A swipe and a long press offer the same record, plus the details and the edit screen (D028).
private struct AsNeededItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let row: AsNeededCard.Row
    let timeZone: TimeZone

    var body: some View {
        HStack(spacing: 12) {
            // At the three largest text sizes the icon gives its width to the name (D013).
            if typeSize < .accessibility3 {
                FormIcon(form: row.look.form, color: row.look.color)
                    .frame(minWidth: 32, minHeight: 44)
            }
            // The name area opens the details, like a row of a part of the day (spec 3 P01).
            NavigationLink(value: row.itemID) {
                // Names wrap and never truncate (spec 5.3).
                Text(row.look.name)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    // Two VoiceOver stops, like the two touch areas: the name, then the record button (spec 3 P01).
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: row.look.name))
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .accessibilityHint(Text("Opens the details"))
            if canRecord {
                AsNeededRecordButton(row: row)
            }
        }
        .swipeActions(edge: .leading) {
            if canRecord { recordButton.tint(appColor.tint) }
        }
        .contextMenu {
            if canRecord {
                recordButton
                Divider()
            }
            Button("Details", systemImage: "info.circle") { model.today.path.append(row.itemID) }
            Button("Edit", systemImage: "pencil") { model.openEditor(for: row.itemID) }
            Button("Archive…", systemImage: "archivebox") {
                model.askToEnd(.archive, itemID: row.itemID, name: row.look.name)
            }
        }
    }

    private var canRecord: Bool {
        row.canRecord || isNotSaved
    }

    private var isNotSaved: Bool {
        model.today.asNeeded.newDose(of: row.itemID) != nil
    }

    /// The same operation as the record button: a new dose now, or the retry of the unsaved one.
    private var recordButton: some View {
        Button {
            model.recordAsNeeded(row)
        } label: {
            if isNotSaved {
                Label("Try Again", systemImage: "arrow.clockwise")
            } else {
                Label("Take Now", systemImage: "plus.circle")
            }
        }
    }
}

/// Records a new dose now. It is no switch: each tap that succeeds adds one dose. The dose and the haptic
/// come after the commit (spec 7.2).
private struct AsNeededRecordButton: View {
    @Environment(AppModel.self) private var model
    let row: AsNeededCard.Row

    var body: some View {
        let isNotSaved = model.today.asNeeded.newDose(of: row.itemID) != nil
        Button {
            model.recordAsNeeded(row)
        } label: {
            Image(systemName: isNotSaved ? "exclamationmark.circle" : "plus.circle")
                .font(.title2)
                .foregroundStyle(isNotSaved ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .symbolMotion(value: isNotSaved)
                .accessibilityHidden(true)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(isNotSaved ? Text("Save \(row.look.name) again") : Text("Record a dose of \(row.look.name)"))
        .accessibilityHint(isNotSaved ? Text("Tries to save it again.") : Text("Records a dose now."))
    }
}

/// One dose of today under its item: the time. A tap opens the correction choices. A swipe and a long
/// press offer the same choices (D028).
private struct AsNeededDoseRow: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @Environment(\.dynamicTypeSize) private var typeSize
    let row: AsNeededCard.Row
    let dose: AsNeededCard.Dose
    let timeZone: TimeZone
    @State private var showsCorrection = false
    @State private var showsTimeEditor = false

    var body: some View {
        let isNotSaved = model.today.asNeeded.correction(of: dose.id) != nil
        Button {
            if isNotSaved { model.retry(dose) } else { showsCorrection = true }
        } label: {
            HStack(spacing: 8) {
                // The label and the value say the state, so VoiceOver reads no image name.
                Group {
                    if isNotSaved {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    } else {
                        Image(systemName: dose.record.status == .skipped ? "minus" : "checkmark")
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityHidden(true)
                statusText
                    .foregroundStyle(isNotSaved ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            // Under the name, past the icon column.
            .padding(.leading, typeSize < .accessibility3 ? 44 : 0)
            .contentShape(Rectangle())
            .motion(.state, value: [isNotSaved, dose.record.status == .skipped])
        }
        .buttonStyle(.plain)
        .confirmationDialog(statusText, isPresented: $showsCorrection, titleVisibility: .visible) {
            if dose.record.status == .taken {
                Button("Change Time…") { showsTimeEditor = true }
            }
            Button("Undo", role: .destructive) { model.undo(dose, in: row) }
        }
        .sheet(isPresented: $showsTimeEditor) {
            // The dose stays on its day, so the time stays on that day too.
            ChangeTimeSheet(name: row.look.name, time: dose.time ?? .now, earliest: startOfDay) {
                model.changeTime(dose, in: row, to: $0)
            }
        }
        .swipeActions(edge: .leading) {
            if isNotSaved { retryButton.tint(appColor.tint) }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isNotSaved { undoButton.tint(.gray) }
        }
        .contextMenu {
            if isNotSaved {
                retryButton
            } else {
                if dose.record.status == .taken {
                    Button("Change Time…", systemImage: "clock") { showsTimeEditor = true }
                }
                undoButton
            }
        }
        .accessibilityLabel(Text("Dose of \(row.look.name)"))
        .accessibilityValue(isNotSaved ? Text("Not saved") : statusText)
        .accessibilityHint(isNotSaved ? Text("Tries to save it again.") : Text("Shows ways to change it."))
    }

    private var undoButton: some View {
        Button("Undo", systemImage: "arrow.uturn.backward") { model.undo(dose, in: row) }
    }

    private var retryButton: some View {
        Button("Try Again", systemImage: "arrow.clockwise") { model.retry(dose) }
    }

    private var statusText: Text {
        let time = dose.time.map { $0.formatted(.rowTime(in: timeZone)) } ?? ""
        return dose.record.status == .skipped ? Text("Skipped at \(time)") : Text("Taken at \(time)")
    }

    private var startOfDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: dose.occurrence.timeZone.identifier) ?? timeZone
        let date = dose.occurrence.plannedDate
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? .now
    }
}
