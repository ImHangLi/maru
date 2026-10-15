import MaruCore
import SwiftUI

/// One row of the timeline, like a row of Recents in Phone: the form icon in the item color, the name, the
/// action in plain words under it, and the time of the action at the end (D032).
///
/// "No record" has its own words and the part of the day in place of a time, so it never looks like
/// "skipped" (spec 4, spec 5.3). The intake time shows in the words when it is not the time of the record (spec 3 P05).
/// The newest row of a dose offers the corrections with a swipe and a long press, as a row of Today does (D028).
/// They use the same record transaction, so the list changes only after the commit (spec 7.2).
struct HistoryEntryRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let entry: HistoryEntry
    @State private var showsTimeEditor = false

    private enum Correction { case none, open, taken, skipped, notSaved }

    /// What the corrections start from. A row that a later action replaced has none.
    private var state: Correction {
        guard entry.isCurrent else { return .none }
        if entry.kind == .notSaved { return .notSaved }
        return switch status {
        case .unrecorded: .open
        case .taken: .taken
        case .skipped: .skipped
        }
    }

    var body: some View {
        let state = state
        let item = model.history.looks[itemID]
        Group {
            switch (state, entry.dose) {
            // A tap on a dose with no record opens the time of the intake at once.
            case (.open, .planned): Button { showsTimeEditor = true } label: { label(item) }.buttonStyle(.plain)
            case (.notSaved, _): Button(action: retry) { label(item) }.buttonStyle(.plain)
            default: label(item)
            }
        }
        .swipeActions(edge: .leading) {
            switch (state, entry.dose) {
            case (.open, .planned), (.skipped, .planned): takenButton.tint(appColor.tint)
            case (.notSaved, _): retryButton.tint(appColor.tint)
            default: EmptyView()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if state == .taken || state == .skipped { undoButton.tint(.gray) }
            // A past dose with no record can be marked as skipped in place (D091).
            if state == .open, case let .planned(dose) = entry.dose { skipButton(dose).tint(.gray) }
        }
        .contextMenu {
            switch (state, entry.dose) {
            case (.open, .planned(let dose)):
                takenButton
                skipButton(dose)
            case (.taken, .planned(let dose)):
                changeTimeButton
                skipButton(dose)
                undoButton
            case (.taken, .asNeeded):
                changeTimeButton
                undoButton
            case (.skipped, .planned):
                takenButton
                undoButton
            case (.skipped, .asNeeded):
                undoButton
            case (.notSaved, _):
                retryButton
            default:
                EmptyView()
            }
        }
        .sheet(isPresented: $showsTimeEditor) {
            ChangeTimeSheet(name: item?.name ?? "", time: suggestedTime, earliest: dayStart, latest: latestTime, save: saveTime)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(state == .none ? Text(verbatim: "") : Text("Swipe or touch and hold to change it."))
    }

    private func label(_ item: TodaySnapshot.ItemLook?) -> some View {
        HStack(spacing: 12) {
            if let item {
                FormIcon(form: item.form, color: item.color, photo: item.imageReference)
                    .frame(minWidth: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                // Names wrap and never truncate (spec 5.3).
                Text(verbatim: item?.name ?? "")
                    .foregroundStyle(.primary)
                Group {
                    if entry.kind == .notSaved {
                        // The words carry the error, also without the color (spec 5.3).
                        Label("Not saved", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    } else {
                        Text(actionText)
                            .foregroundStyle(.secondary)
                    }
                    // At the accessibility sizes the time goes under the action, so the name keeps its width.
                    if typeSize.isAccessibilitySize {
                        Text(whenText)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                if let detail = detailText(item) {
                    Text(verbatim: detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                Text(whenText)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .numberMotion(value: whenText)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: Corrections

    /// The time sheet saves it. The store keeps the earlier events (T20).
    private var takenButton: some View {
        Button("Taken", systemImage: "checkmark") { showsTimeEditor = true }
    }

    private func skipButton(_ dose: HistoryDose) -> some View {
        Button("Skip", systemImage: "minus.circle") { model.markSkipped(dose) }
    }

    private var changeTimeButton: some View {
        Button("Change Time…", systemImage: "clock") { showsTimeEditor = true }
    }

    private var undoButton: some View {
        Button("Undo", systemImage: "arrow.uturn.backward") {
            switch entry.dose {
            case let .planned(dose): model.undo(dose)
            case let .asNeeded(dose): model.undo(dose)
            }
        }
    }

    private var retryButton: some View {
        Button("Try Again", systemImage: "arrow.clockwise", action: retry)
    }

    private func retry() {
        switch entry.dose {
        case let .planned(dose): model.retry(dose)
        case let .asNeeded(dose): model.retry(dose)
        }
    }

    private func saveTime(_ time: Date) {
        switch entry.dose {
        case let .planned(dose): model.markTaken(dose, at: time)
        case let .asNeeded(dose): model.changeTime(dose, to: time)
        }
    }

    // MARK: Dose

    private var itemID: ItemID {
        switch entry.dose {
        case let .planned(dose): dose.itemID
        case let .asNeeded(dose): dose.occurrence.itemID
        }
    }

    private var status: OccurrenceStatus {
        switch entry.dose {
        case let .planned(dose): dose.record.status
        case let .asNeeded(dose): dose.record.status
        }
    }

    private var zone: NamedTimeZone {
        switch entry.dose {
        case let .planned(dose): dose.occurrence.timeZone
        case let .asNeeded(dose): dose.occurrence.timeZone
        }
    }

    /// The date of the dose in its own time zone.
    private var plannedDate: LocalDate {
        switch entry.dose {
        case let .planned(dose): dose.occurrence.plannedDate
        case let .asNeeded(dose): dose.occurrence.plannedDate
        }
    }

    /// The time of the intake that counts now.
    private var takenAt: Date? {
        let event = switch entry.dose {
        case let .planned(dose): dose.record.currentEvent
        case let .asNeeded(dose): dose.record.currentEvent
        }
        return event.flatMap { $0.action == .taken ? $0.occurredAt : nil }
    }

    // MARK: Times

    private var timeZone: TimeZone {
        TimeZone(identifier: zone.identifier) ?? .current
    }

    private var dayStart: Date {
        zone.resolve(try! WallClockTime(hour: 0, minute: 0), on: plannedDate).earliestInstant
    }

    /// A planned dose: the end of the day after the dose, so a dose after midnight fits. An as-needed dose
    /// stays on its day. Never after now.
    private var latestTime: Date {
        let days = if case .planned = entry.dose { 2 } else { 1 }
        let end = zone.resolve(try! WallClockTime(hour: 0, minute: 0), on: plannedDate.adding(days: days)).earliestInstant
        return min(end.addingTimeInterval(-60), .now)
    }

    /// The taken time, else the planned time that the user set. The user confirms it with Save.
    private var suggestedTime: Date {
        let planned: Date = switch entry.dose {
        case let .planned(dose): dose.occurrence.resolvedTime.earliestInstant
        case .asNeeded: latestTime
        }
        return min(max(takenAt ?? planned, dayStart), latestTime)
    }

    /// The time alone on the day of the dose, else with the date, for example "Oct 11, 9:12 PM".
    private func text(of instant: Date) -> String {
        guard LocalDate(instant, in: zone) != plannedDate else { return instant.formatted(.rowTime(in: timeZone)) }
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().hour().minute()
        style.timeZone = timeZone
        return instant.formatted(style)
    }

    // MARK: Words

    private var actionText: String {
        guard let event = entry.event else { return String(localized: "No record") }
        let minute = { (date: Date) in Int(date.timeIntervalSinceReferenceDate / 60) }
        switch entry.kind {
        case .taken:
            // The intake time shows only when it is not the time of the record (spec 3 P05).
            if minute(event.occurredAt) == minute(event.recordedAt) { return String(localized: "Taken") }
            return String(localized: "Taken at \(text(of: event.occurredAt))")
        case .timeChanged: return String(localized: "Time changed to \(text(of: event.occurredAt))")
        case .skipped: return String(localized: "Skipped")
        case .undone: return String(localized: "Undone")
        case .noRecord: return String(localized: "No record")
        case .notSaved: return String(localized: "Not saved")
        }
    }

    /// The line under the action (D091): "Replaced" for an action that a later one replaced, the planned time and the amount of
    /// a planned dose, the amount of an as-needed dose, and the form when another item has the same name, so two items
    /// with one name differ (spec 3 T34). The newest row of a dose has no mark: it is the record that counts.
    private func detailText(_ item: TodaySnapshot.ItemLook?) -> String? {
        var parts: [String] = []
        if entry.event != nil, !entry.isCurrent { parts.append(String(localized: "Replaced")) }
        switch entry.dose {
        case let .planned(dose):
            let time = dose.occurrence.resolvedTime.earliestInstant.formatted(.rowTime(in: timeZone))
            parts.append(String(localized: "Planned \(time)"))
            if let amount = model.history.amounts[dose.occurrence.scheduleVersionID] { parts.append(amount.text) }
        case let .asNeeded(dose):
            if let amount = dose.occurrence.dose { parts.append(amount.text) }
        }
        if let item, item.form != .unknown, model.history.looks.values.contains(where: {
            $0.itemID != item.itemID && $0.name.localizedCaseInsensitiveCompare(item.name) == .orderedSame
        }) {
            parts.append(item.form.localizedName)
        }
        return parts.isEmpty ? nil : parts.formatted(.list(type: .and, width: .narrow))
    }

    /// The time of the action. A dose with no record has no action, so it shows its part of the day.
    private var whenText: String {
        if let event = entry.event { return text(of: event.recordedAt) }
        guard case let .planned(dose) = entry.dose else { return "" }
        return String(localized: DayPart(dose.occurrence.plannedTime).title)
    }
}
