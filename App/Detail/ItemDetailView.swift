import MaruCore
import SwiftUI

/// The detail of one item (spec 3 P04): the name, the form icon, the plan, the note, and the 7-day strip of
/// the records (D057). Edit opens the edit screen. The menu "Item Options…" holds the rarer changes.
///
/// It never says that the user finished a product, and it has no refill action (T04, T09).
struct ItemDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let itemID: ItemID

    @State private var detail: ItemDetail?
    @State private var readFailed = false
    @State private var changeFailed = false
    @State private var isChanging = false

    var body: some View {
        Group {
            if let detail {
                content(detail)
            } else if readFailed {
                ContentUnavailableView {
                    Label("Can’t Show Item", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Maru couldn’t read this item.")
                } actions: {
                    Button("Try Again") { Task { await load() } }
                }
            }
        }
        // The gray page with white cards, also while the detail loads (D028).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        #if DEBUG
        .modifier(DebugDataBanner())
        #endif
        .navigationTitle(Text(verbatim: detail?.item.name ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let detail, !detail.item.isArchived {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { model.openEditor(for: itemID) }
                }
            }
        }
        // Each new read of the store, for example after a save in the edit screen, reads the detail again.
        .task(id: model.content) { await load() }
        .alert("Not Changed", isPresented: $changeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This change didn’t save. Please try again.")
        }
    }

    private func load() async {
        do {
            guard let next = try await model.detail(of: itemID) else {
                // The item is gone from the store, for example after a delete. Go back to the list.
                dismiss()
                return
            }
            if detail?.item.isArchived == false, next.item.isArchived {
                // An archive or a replacement archived this item. Go back to Today or My Items.
                dismiss()
                return
            }
            detail = next
            readFailed = false
        } catch {
            readFailed = detail == nil
        }
    }

    private func content(_ detail: ItemDetail) -> some View {
        let item = detail.item
        return List {
            Section {
                DetailHeader(item: item, remindersOff: detail.schedule?.isEnabled == false)
                // The owner, only with a second active member (T57). "Edit" changes it, so the user reads "Records move with the
                // item." before the save (D128, D129).
                if model.hasFamily, let owner = model.people.first(where: { $0.id == item.personID }) {
                    LabeledContent("For") {
                        HStack(spacing: 8) {
                            MemberAvatar(owner, side: 24)
                            Text(verbatim: owner.displayName)
                        }
                    }
                }
            }
            ScheduleSection(
                schedule: detail.schedule,
                nextDose: item.isArchived ? nil : detail.nextDose,
                status: detail.schedule.flatMap { model.reminderStatus[$0.id] },
                coverageEnd: detail.schedule.flatMap { model.reminderCoverageEnds[$0.id] },
                asksForReminder: detail.schedule?.isEnabled == true && !item.isArchived
            )
            if let note = item.intakeNote {
                Section("Note") {
                    switch note {
                    case .preset(.withFood): Text("With food")
                    case .preset(.emptyStomach): Text("On an empty stomach")
                    case let .text(text): Text(verbatim: text)
                    }
                }
            }
            // A new item with the same values for another member (D128). It shows only with a second active member.
            let others = model.activePeople.filter { $0.id != item.personID }
            if !item.isArchived, model.hasFamily, !others.isEmpty {
                Section {
                    Menu {
                        ForEach(others, id: \.id) { person in
                            Button {
                                model.openEditorForCopy(item.id, for: person.id)
                            } label: {
                                Label {
                                    Text(verbatim: person.displayName)
                                } icon: {
                                    MemberAvatar.menuImage(.member(person))
                                }
                            }
                        }
                    } label: {
                        Label("Add for…", systemImage: "plus.square.on.square")
                            .labelStyle(RowLabelStyle())
                    }
                }
            }
            WeekSection(week: detail.week, item: item)
            MonthSection(month: detail.month, item: item)
            Section {
                if item.isArchived {
                    Button("Restore") { change { try await model.setArchived(false, for: item.id) } }
                        .rowText()
                    Button("Delete Item…", role: .destructive) {
                        model.askToEnd(.delete, itemID: item.id, name: item.name)
                    }
                } else {
                    // A plain row at the end, so the rare changes stay out of the way (spec 3 P04). It opens a
                    // system menu, not a dialog, so an archive or a delete has one confirmation (D033).
                    Menu {
                        Button("Replace with a New Product…", systemImage: "arrow.triangle.2.circlepath") {
                            model.openEditorForNewProduct(item.id)
                        }
                        if let schedule = detail.schedule {
                            if schedule.isEnabled {
                                Button("Turn Off Reminders", systemImage: "bell.slash") {
                                    change { try await model.setReminders(on: false, for: item) }
                                }
                            } else {
                                Button("Turn On Reminders", systemImage: "bell") {
                                    change { try await model.setReminders(on: true, for: item) }
                                }
                            }
                        }
                        Button("Archive…", systemImage: "archivebox") {
                            model.askToEnd(.archive, itemID: item.id, name: item.name)
                        }
                        Button("Delete Item…", systemImage: "trash", role: .destructive) {
                            model.askToEnd(.delete, itemID: item.id, name: item.name)
                        }
                    } label: {
                        Text("Item Options…").rowText()
                    }
                }
            }
            .disabled(isChanging)
        }
        .listStyle(.insetGrouped)
        // A saved edit or a new reminder state adds and removes rows here. They move with the layout motion (D030).
        .motion(.layout, value: detail)
        .motion(.layout, value: detail.schedule.flatMap { model.reminderStatus[$0.id] })
    }

    /// Runs one change. The page shows the change only after the commit (spec 7.2). A failure changes nothing.
    private func change(_ operation: @escaping () async throws -> Void) {
        isChanging = true
        Task {
            defer { isChanging = false }
            do {
                try await operation()
            } catch {
                changeFailed = true
            }
        }
    }
}

/// The form icon and the name, and the state of the reminders when they are off (T07).
private struct DetailHeader: View {
    let item: Item
    let remindersOff: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                FormIcon(form: item.form, color: item.color, photo: item.imageReference)
                // Names wrap and never truncate (spec 5.3).
                Text(verbatim: item.name)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if item.isArchived {
                Label("Archived", systemImage: "archivebox")
            } else if remindersOff {
                Label {
                    Text("You can still record it with reminders off.")
                } icon: {
                    Image(systemName: "bell.slash")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// The plan that applies now: the time of each slot under its slot name, the days, the next dose of a plan
/// that repeats every second day (D036), the amount, the
/// kept time zone of a medication when the device is in another zone (spec 8.5), and the state of the
/// reminder in the system (spec 8.1, T03). A save shows no message, so a failed reminder stays visible here.
private struct ScheduleSection: View {
    @Environment(\.openURL) private var openURL
    let schedule: Schedule?
    /// The day of the next dose of a plan that repeats every second day. `nil` for every other plan.
    let nextDose: ItemDetail.NextDose?
    /// `nil` until a run of the reminder engine reports this schedule.
    let status: ReminderStatus?
    /// The last dated reminder of the plan, when it has dated reminders (D089).
    let coverageEnd: Date?
    /// The plan asks for a reminder: its reminders are on, and the item is not archived.
    let asksForReminder: Bool

    var body: some View {
        Section {
            rows
            if asksForReminder, status == .notificationsOff {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .rowText()
            }
        } header: {
            Text("Plan")
        } footer: {
            if let problem { Text(problem) }
        }
    }

    @ViewBuilder private var rows: some View {
        if let version = schedule?.versions.last {
            ForEach(version.slotTimes.sorted { $0.time < $1.time }, id: \.slotID) { slot in
                LabeledContent {
                    Text(verbatim: SchedulePreview.format(hour: slot.time.hour, minute: slot.time.minute))
                } label: {
                    Text(DayPart(slot.time).title)
                }
            }
            LabeledContent("Days") {
                Text(verbatim: SchedulePreview.days(of: version))
            }
            if let nextDose {
                LabeledContent("Next Dose") {
                    switch nextDose.daysFromToday {
                    case 0: Text("Today")
                    case 1: Text("Tomorrow")
                    case 2...6: Text(verbatim: weekday(nextDose.date))
                    // After a pause, a weekday alone does not tell the week.
                    default: Text(verbatim: nextDose.date.shortLabel)
                    }
                }
            }
            if let dose = version.dose {
                LabeledContent("Amount") { Text(verbatim: dose.text) }
            }
            if case let .fixed(zone) = version.timeZonePolicy, zone != NamedTimeZone(device: .current, at: .now) {
                LabeledContent("Time Zone") { Text(verbatim: SchedulePreview.city(zone)) }
            }
            if let reminder {
                LabeledContent("Reminder") { reminder }
            }
        } else {
            Text("No times set")
                .foregroundStyle(.secondary)
        }
    }

    /// A plan date has no time and no zone, so it uses a fixed time in UTC, as the edit screen does.
    private func weekday(_ date: LocalDate) -> String {
        let calendar = SchedulePreview.utcCalendar
        let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? .now
        var style = Date.FormatStyle.dateTime.weekday(.wide)
        style.timeZone = .gmt
        return value.formatted(style)
    }

    /// "On" only when the system holds every request. A plan with reminders off shows no row: the header says it.
    private var reminder: Text? {
        if asksForReminder {
            switch status {
            case .set?: Text("On")
            case .notificationsOff?, .tooMany?, .notSet?: Text("Not Set")
            case .notConfirmed?: Text("Not Confirmed")
            case .off?, .notAsked?, nil: nil
            }
        } else {
            status == .notConfirmed ? Text("Not Confirmed") : nil
        }
    }

    /// The plan counts days, or its last dated reminder is near.
    private var hasDatedReminders: Bool {
        schedule?.versions.last?.dayCycle != nil || (coverageEnd.map { $0.timeIntervalSinceNow < 21 * 86_400 } ?? false)
    }

    private var coverageText: LocalizedStringKey {
        guard let coverageEnd else { return "Maru sets the reminders of the next 7 dose days each time you open it." }
        let date = coverageEnd.formatted(date: .abbreviated, time: .omitted)
        return "Reminders are set until \(date). Maru sets them again each time you open it."
    }

    private var problem: LocalizedStringKey? {
        guard asksForReminder else {
            return status == .notConfirmed ? "The reminders may still be on until Maru checks again." : nil
        }
        return switch status {
        case .notificationsOff?: "Notifications are off for Maru."
        case .tooMany?: "The plan has too many times for iPhone."
        case .notSet?: "Maru tries again when you open it."
        case .notConfirmed?: "Maru checks again when you open it."
        // iPhone has no repeating reminder for a plan that counts days, so "On" has a limit here.
        // A plan with a record before its time has a short limit too. The page states it (D036, D065, D089).
        case .set? where hasDatedReminders:
            coverageText
        case .set?, .off?, .notAsked?, nil: nil
        }
    }
}

/// The strip of the last 7 days, the same view and rule as a row of History (D054, D057), after the form icon.
/// A line under it counts the doses that are taken, skipped, and with no record (D061). The History tab has the
/// records.
private struct WeekSection: View {
    /// `nil` when the item had no planned dose and no taken as-needed dose in the week.
    let week: HistoryItemWeek?
    let item: Item

    var body: some View {
        Section("Last 7 Days") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    FormIcon(form: item.form, color: item.color, photo: item.imageReference)
                        .accessibilityHidden(true)
                    WeekStrip(marks: week?.marks ?? Array(repeating: HistoryDayMark.none, count: 7), color: item.color.color)
                }
                // The counts stand side by side, or one under the other when the row is too narrow.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { countTexts }
                    VStack(alignment: .leading, spacing: 2) { countTexts }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .numberMotion(value: counts)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            // The strip says nothing to VoiceOver, so the row reads the counts.
            .accessibilityElement(children: .combine)
        }
    }

    private var countTexts: some View {
        ForEach(counts, id: \.self) { Text(verbatim: $0) }
    }

    /// For example "Taken: 1", "Skipped: 0", and "No record: 1". An as-needed item has only the taken doses.
    private var counts: [String] {
        guard let week else { return [String(localized: "No records in the last 7 days.")] }
        let taken = String(localized: "Taken: \(week.takenDoses)", comment: "Item detail: the doses taken in the last 7 days. Example: Taken: 5.")
        if week.isAsNeeded { return [taken] }
        return [
            taken,
            String(localized: "Skipped: \(week.skippedDoses)", comment: "Item detail: the planned doses skipped in the last 7 days. Example: Skipped: 1."),
            String(localized: "No record: \(week.unrecordedDoses)", comment: "Item detail: the planned doses with no record in the last 7 days. Example: No record: 1."),
        ]
    }
}

/// The counts of the last 30 days, and the way to the full log (D091). Plain numbers: no percent, no streak, no score.
/// The full log lists every day of the item, also an archived item and a day older than the graph.
///
/// The counts are part of Maru Pro (D130). A free user sees one quiet row that opens the paywall. "All Records" stays free,
/// so no record is hidden.
private struct MonthSection: View {
    @Environment(AppModel.self) private var model
    let month: ItemSummary?
    let item: Item

    var body: some View {
        Section("Last 30 Days") {
            if model.pro.isPro {
                ForEach(counts, id: \.self) { Text(verbatim: $0) }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .numberMotion(value: counts)
            } else {
                Button { model.presentPaywall(reason: .insights) } label: {
                    LabeledContent("30-Day Counts") { ProBadge() }
                }
                .tint(.primary)
            }
            NavigationLink {
                ItemLogView(itemID: item.id)
            } label: {
                Text("All Records")
            }
        }
    }

    /// For example "Taken: 26 of 30", "Skipped: 1", and "No record: 3". An as-needed item has only the taken doses.
    private var counts: [String] {
        guard let month else { return [String(localized: "No records in the last 30 days.")] }
        let skipped = String(localized: "Skipped: \(month.skipped)", comment: "Item detail: the planned doses skipped in the last 30 days. Example: Skipped: 1.")
        let noRecord = String(localized: "No record: \(month.noRecord)", comment: "Item detail: the planned doses with no record in the last 30 days. Example: No record: 1.")
        let asNeeded = String(localized: "As needed: \(month.asNeededTaken)", comment: "Item detail and summary: the doses taken as needed in the period. They have no plan. Example: As needed: 3.")
        if month.planned == 0 { return [String(localized: "Taken: \(month.asNeededTaken)")] }
        let taken = String(localized: "Taken: \(month.taken) of \(month.planned)", comment: "Item detail: the planned doses taken of the planned doses in the last 30 days. Example: Taken: 26 of 30.")
        return month.asNeededTaken > 0 ? [taken, skipped, noRecord, asNeeded] : [taken, skipped, noRecord]
    }
}
