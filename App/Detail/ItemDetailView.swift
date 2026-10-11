import MaruCore
import SwiftUI

/// The detail of one item (spec 3 P04): the name, the form icon, the plan, the note, and the records of the
/// last seven days. Edit opens the edit screen. The menu "Change or End This Item…" holds the rarer changes.
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
        .alert("Not changed", isPresented: $changeFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Maru couldn’t save this change. Try again.")
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
            }
            ScheduleSection(
                schedule: detail.schedule,
                status: detail.schedule.flatMap { model.reminderStatus[$0.id] },
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
            RecentSection(recent: detail.recent)
            Section {
                if item.isArchived {
                    Button("Restore") { change { try await model.setArchived(false, for: item.id) } }
                    Button("Delete Item…", role: .destructive) {
                        model.askToEnd(.delete, itemID: item.id, name: item.name)
                    }
                } else {
                    // A plain row at the end, so the rare changes stay out of the way (spec 3 P04). It opens a
                    // system menu, not a dialog, so an archive or a delete has one confirmation (D033).
                    Menu("Change or End This Item…") {
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
                FormIcon(form: item.form, color: item.color)
                // Names wrap and never truncate (spec 5.3).
                Text(verbatim: item.name)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if item.isArchived {
                Label("Archived", systemImage: "archivebox")
                    .foregroundStyle(.secondary)
            } else if remindersOff {
                Label {
                    Text("You can still record it with reminders off.")
                } icon: {
                    Image(systemName: "bell.slash")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// The plan that applies now: the time of each slot under its slot name, the days, the amount, the
/// kept time zone of a medication when the device is in another zone (spec 8.5), and the state of the
/// reminder in the system (spec 8.1, T03). A save shows no message, so a failed reminder stays visible here.
private struct ScheduleSection: View {
    @Environment(\.openURL) private var openURL
    let schedule: Schedule?
    /// `nil` until a run of the reminder engine reports this schedule.
    let status: ReminderStatus?
    /// The plan asks for a reminder: its reminders are on, and the item is not archived.
    let asksForReminder: Bool

    var body: some View {
        Section {
            rows
            if asksForReminder, status == .notificationsOff {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
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
                Text(verbatim: SchedulePreview.days(version.weeklyRule.weekdays))
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

    private var problem: LocalizedStringKey? {
        guard asksForReminder else {
            return status == .notConfirmed ? "The reminders may still be on until Maru checks again." : nil
        }
        return switch status {
        case .notificationsOff?: "Notifications are off for Maru."
        case .tooMany?: "The plan has too many times for iPhone."
        case .notSet?: "Maru tries again when you open it."
        case .notConfirmed?: "Maru checks again when you open it."
        case .set?, .off?, .notAsked?, nil: nil
        }
    }
}

/// The taken and skipped records of the last seven days, newest first (D019). The history tab has the rest.
private struct RecentSection: View {
    let recent: [ItemDetail.Recent]

    var body: some View {
        Section("Last 7 Days") {
            if recent.isEmpty {
                Text("No records in the last 7 days.")
                    .foregroundStyle(.secondary)
            }
            ForEach(recent) { entry in
                LabeledContent {
                    switch entry.event.action {
                    case .taken: Text("Taken \(entry.event.occurredAt.formatted(date: .omitted, time: .shortened))")
                    default: Text("Skipped")
                    }
                } label: {
                    Text(verbatim: day(entry.plannedDate))
                    if entry.isAsNeeded {
                        Text("As Needed")
                    } else {
                        Text(DayPart(entry.plannedTime).title)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// A plan date has no time and no zone, so it uses a fixed time in UTC, as the edit screen does.
    private func day(_ date: LocalDate) -> String {
        let calendar = SchedulePreview.utcCalendar
        let value = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day)) ?? .now
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        style.timeZone = .gmt
        return value.formatted(style)
    }
}
