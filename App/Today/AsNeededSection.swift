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
                AsNeededItemRow(row: row)
                ForEach(row.doses) { AsNeededDoseRow(row: row, dose: $0, timeZone: timeZone) }
            }
        } header: {
            Text("As Needed")
                .textCase(nil)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
        }
        .alert(
            model.today.asNeeded.failure?.kind.alertTitle(changed: "Today Changed") ?? Text("Not Saved"),
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
            failure.kind.alertMessage
        }
    }
}

/// One item: the form icon, the name, and the record button. Like a row of a part of the day, the name area
/// never records (spec 3 P01). A second line shows the usual amount and the last dose (D091).
/// A swipe and a long press offer the same record, plus the details and the edit screen (D028).
private struct AsNeededItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let row: AsNeededCard.Row

    var body: some View {
        HStack(spacing: 12) {
            // At the three largest text sizes the icon gives its width to the name (D013).
            if typeSize < .accessibility3 {
                FormIcon(form: row.look.form, color: row.look.color, photo: row.look.imageReference)
                    .frame(minWidth: 32, minHeight: 44)
            }
            // The name area opens the details, like a row of a part of the day (spec 3 P01).
            NavigationLink(value: row.itemID) {
                // Names wrap and never truncate (spec 5.3).
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.look.name)
                    if let detail {
                        Text(verbatim: detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                // Two VoiceOver stops, like the two touch areas: the name, then the record button (spec 3 P01).
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: row.look.name))
                .accessibilityValue(Text(verbatim: detail ?? ""))
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
            Button("Delete Item…", systemImage: "trash", role: .destructive) {
                model.askToEnd(.delete, itemID: row.itemID, name: row.look.name)
            }
        }
    }

    private var canRecord: Bool {
        row.canRecord || isNotSaved
    }

    /// The amount that a new dose gets, and when the user last took a dose, also on an earlier day (D091).
    private var detail: String? {
        var parts: [String] = []
        if row.canRecord, let amount = row.amount { parts.append(amount.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if let last = row.lastTaken { parts.append(String(localized: "Last dose \(lastDoseText(last))")) }
        return parts.isEmpty ? nil : parts.formatted(.list(type: .and, width: .narrow))
    }

    /// The time alone for today, else the day and the time, for example "Yesterday, 9:12 PM" or "Oct 9, 9:12 PM".
    private func lastDoseText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday, \(date.formatted(date: .omitted, time: .shortened))")
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
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
                Label("Record Dose", systemImage: "plus.circle")
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
        .buttonStyle(.pressScale)
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
            HStack(spacing: 12) {
                // An invisible copy of the form icon of the item row keeps the column of the icon at every text
                // size, so the dose lines up under the name.
                if typeSize < .accessibility3 {
                    FormIcon(form: row.look.form, color: row.look.color, photo: row.look.imageReference)
                        .frame(minWidth: 32)
                        .hidden()
                }
                HStack(spacing: 8) {
                    // The label and the value say the state, so VoiceOver reads no image name.
                    Group {
                        if isNotSaved {
                            Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                        } else {
                            Image(systemName: dose.record.status == .skipped ? "minus" : "checkmark")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
                    // A state shows in the text color, never in gray (design principle 6).
                    statusText
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .numberMotion(value: dose.time)
                    Spacer(minLength: 0)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
        // A skipped dose says only "Skipped", as a skipped row of Today does (D058).
        if dose.record.status == .skipped { return Text("Skipped") }
        let time = dose.time.map { $0.formatted(.rowTime(in: timeZone)) } ?? ""
        return Text("Taken at \(time)")
    }

    private var startOfDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: dose.occurrence.timeZone.identifier) ?? timeZone
        let date = dose.occurrence.plannedDate
        return calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? .now
    }
}
