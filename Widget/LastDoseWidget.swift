import AppIntents
import MaruCore
import MaruDatabase
import SwiftUI
import WidgetKit

/// "Last Dose": the newest taken dose across the active items, with its name, amount, and time (D108).
/// With "Show Names in Reminders" off, it shows "Dose recorded" and the time, and no name or amount (D029).
/// A tap opens the detail of the item.
struct LastDoseWidget: Widget {
    static let kind = "com.imhangli.maru.lastDose"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NoConfiguration.self, provider: LastDoseProvider()) { entry in
            LastDoseWidgetView(entry: entry)
        }
        .configurationDisplayName("Last Dose")
        .description("See your newest taken dose and its time.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

struct LastDoseEntry: TimelineEntry {
    enum Content {
        /// `nil` when no active item has a taken dose.
        case dose(LastDose?)
        /// The database is locked, not there yet, or not readable. The widget asks to open Maru.
        case unavailable
    }

    let date: Date
    let content: Content
    let tint: ItemColor
    /// "Show Names in Reminders" in the App Group (D029).
    let showsNames: Bool
}

/// Reads the newest taken dose from the database in the App Group. It only reads (D048, D108).
struct LastDoseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LastDoseEntry {
        // A sample for the gallery, as `WidgetDay.sample`. It has no name of the user.
        let sample = LastDose(
            itemID: ItemID(), name: "Vitamin D", takenAt: Date().addingTimeInterval(-2 * 60 * 60), amount: Dose("1 capsule")
        )
        return LastDoseEntry(date: Date(), content: .dose(sample), tint: AppGroup.appColor, showsNames: true)
    }

    func snapshot(for configuration: NoConfiguration, in context: Context) async -> LastDoseEntry {
        if context.isPreview { return placeholder(in: context) }
        return Self.entries(at: Date()).first!
    }

    func timeline(for configuration: NoConfiguration, in context: Context) async -> Timeline<LastDoseEntry> {
        let now = Date()
        let entries = Self.entries(at: now)
        guard case .dose = entries[0].content else {
            // A locked iPhone, or a database that is not there. Try again soon. A launch of the app also reloads.
            return Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60)))
        }
        // The app reloads the timeline after each record. Read again at the last change of the text at the latest.
        return Timeline(entries: entries, policy: .after(entries.last!.date.addingTimeInterval(60)))
    }

    /// One entry for now, and one at each change of the time text, so "2 hr. ago" moves with no reload.
    private static func entries(at now: Date) -> [LastDoseEntry] {
        let tint = AppGroup.appColor
        let showsNames = AppGroup.showsNames
        let unavailable = [LastDoseEntry(date: now, content: .unavailable, tint: tint, showsNames: showsNames)]
        guard let directory = AppGroup.databaseDirectory else { return unavailable }
        // `try?` would flatten "no dose" into a failure, so the read keeps the two apart.
        let dose: LastDose?
        do { dose = try LocalStore.readLastDoseForWidget(in: directory) } catch { return unavailable }
        let dates = [now] + (dose.map { LastDoseTime.changes(after: now, takenAt: $0.takenAt) } ?? [])
        return dates.map { LastDoseEntry(date: $0, content: .dose(dose), tint: tint, showsNames: showsNames) }
    }
}

/// The time of the last dose as the widget writes it (D108).
enum LastDoseTime {
    /// Today: the time since the dose, for example "2 hr. ago". Yesterday: "Yesterday, 6:49 PM". Earlier: the date and the time.
    /// The time since the dose goes down to a step of 5 minutes in the first hour and of 1 hour after it, so the text
    /// changes only at the entries of `changes`. The first 5 minutes are "now".
    static func text(_ takenAt: Date, at date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(takenAt, inSameDayAs: date) {
            let elapsed = max(0, date.timeIntervalSince(takenAt))
            let step: TimeInterval = elapsed < 60 * 60 ? 5 * 60 : 60 * 60
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.dateTimeStyle = .named
            return formatter.localizedString(fromTimeInterval: -(elapsed / step).rounded(.down) * step)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: date), calendar.isDate(takenAt, inSameDayAs: yesterday) {
            return String(localized: "Yesterday, \(takenAt.formatted(date: .omitted, time: .shortened))")
        }
        return takenAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// The instants after `now` at which the text changes: every 5 minutes in the first hour after the dose,
    /// then each full hour after it until midnight, and the next two midnights.
    static func changes(after now: Date, takenAt: Date) -> [Date] {
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let minutes = stride(from: 5, to: 60, by: 5).map { takenAt.addingTimeInterval(Double($0) * 60) }
        let hours = (1...24).map { takenAt.addingTimeInterval(Double($0) * 60 * 60) }
        let midnights = [midnight, calendar.date(byAdding: .day, value: 1, to: midnight)!]
        return (minutes + hours).filter { $0 > now && $0 < midnight } + midnights
    }
}

private struct LastDoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LastDoseEntry

    private var isLockScreen: Bool {
        family == .accessoryRectangular || family == .accessoryInline
    }

    var body: some View {
        content
            // The Lock Screen draws its own background.
            .containerBackground(for: .widget) {
                if isLockScreen { Color.clear } else { Color(.systemBackground) }
            }
    }

    @ViewBuilder private var content: some View {
        switch entry.content {
        case .unavailable where isLockScreen:
            Text("Open Maru to update.")
                .font(.caption)
                .widgetURL(AppGroup.todayURL(nil))
        case .unavailable:
            UnavailableView()
        case .dose(nil):
            empty
        case let .dose(dose?):
            Group {
                switch family {
                case .accessoryInline:
                    Label {
                        Text("\(title(dose)), \(LastDoseTime.text(dose.takenAt, at: entry.date))")
                    } icon: {
                        Image(systemName: "pills.fill")
                    }
                case .accessoryRectangular:
                    rectangular(dose)
                default:
                    small(dose)
                }
            }
            .widgetURL(AppGroup.itemURL(dose.itemID))
        }
    }

    /// No taken dose yet. The words are warm and say no judgment (D101).
    @ViewBuilder private var empty: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("No records yet", systemImage: "pills.fill")
            case .accessoryRectangular:
                Text("Your last dose will show here.")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer(minLength: 4)
                    Text("Your last dose will show here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .widgetURL(AppGroup.todayURL(nil))
    }

    private var header: some View {
        HStack {
            Text("Last Dose")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(entry.tint.tint)
            Spacer(minLength: 0)
            CapsuleMark(status: .taken, tint: entry.tint.tint, size: 24)
                .accessibilityHidden(true)
        }
    }

    /// The item name, or "Dose recorded" when the names are off.
    private func title(_ dose: LastDose) -> String {
        entry.showsNames ? dose.name : String(localized: "Dose recorded", comment: "Last Dose widget: the text in place of the item name when \"Show Names in Reminders\" is off (D029, D108).")
    }

    /// The amount, only with names on. An amount can tell what the item is.
    private func amount(_ dose: LastDose) -> Dose? {
        entry.showsNames ? dose.amount : nil
    }

    private func small(_ dose: LastDose) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            header
            Spacer(minLength: 4)
            Text(title(dose))
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            if let amount = amount(dose) {
                Text(amount.text).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(LastDoseTime.text(dose.takenAt, at: entry.date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The layout of the system Lock Screen widgets: a symbol and a bold first line, then plain lines (D094).
    private func rectangular(_ dose: LastDose) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "pills.fill").widgetAccentable()
                Text(title(dose))
            }
            .font(.headline)
            Text(LastDoseTime.text(dose.takenAt, at: entry.date))
            if let amount = amount(dose) {
                Text(amount.text)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }
}
