import MaruCore
import MaruDatabase
import SwiftUI
import WidgetKit

/// "Next Dose": the next open dose of today on the Lock Screen, with its time, the time left, and the names (D113).
/// It is free. It needs no open of the app: its timeline has an entry at each open dose time of today and one at
/// midnight, and the app reloads it after each record (D108). A tap opens Today.
struct NextDoseWidget: Widget {
    static let kind = "com.imhangli.maru.nextDose"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NoConfiguration.self, provider: NextDoseProvider()) { entry in
            NextDoseWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Dose")
        .description("See your next dose and the time left.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// The open doses of one day by planned time, and the progress of the day (D113).
struct NextDoseDay: Sendable {
    /// The open doses of one planned time, in the order of Today.
    struct Time: Sendable {
        let plannedAt: Date
        let part: DayPart
        let names: [String]
    }

    /// In the order of the day.
    let open: [Time]
    let taken: Int
    let total: Int
    let timeZone: TimeZone
    /// The time after which the day is not current any more (`TodaySnapshot.expiresAt`).
    let expiresAt: Date

    /// The dose that the widget shows at `date`: the open dose of the latest planned time that has come, else the first
    /// one to come. So a dose stays until it has a record or the time of the next open dose comes.
    func next(at date: Date) -> Time? {
        open.last { $0.plannedAt <= date } ?? open.first
    }
}

extension NextDoseDay {
    init(_ today: TodaySnapshot) {
        let entries = today.entries
        total = entries.count
        taken = entries.filter { $0.record.status == .taken }.count
        let byTime = Dictionary(grouping: entries.filter(\.isOpen)) { $0.occurrence.plannedInstant }
        open = byTime.keys.sorted().map { plannedAt in
            let doses = byTime[plannedAt]!
            return Time(plannedAt: plannedAt, part: DayPart(doses[0].occurrence.plannedTime), names: doses.map(\.look.name))
        }
        timeZone = TimeZone(identifier: today.timeZone.identifier) ?? .current
        expiresAt = today.expiresAt
    }
}

struct NextDoseEntry: TimelineEntry {
    enum Content {
        case day(NextDoseDay)
        /// The database is locked, not there yet, or not readable. The widget asks to open Maru.
        case unavailable
    }

    let date: Date
    let content: Content
    /// "Show Names in Reminders" in the App Group (D029, D108).
    let showsNames: Bool
}

/// Reads today from the database in the App Group, as the "Today" widget does. It only reads (D048, D113).
struct NextDoseProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NextDoseEntry {
        // A sample for the gallery. It has no name of the user.
        let now = Date()
        let sample = NextDoseDay(
            open: [.init(plannedAt: now.addingTimeInterval(45 * 60), part: .morning, names: ["Vitamin D", "Omega 3"])],
            taken: 1, total: 3, timeZone: .current, expiresAt: .distantFuture
        )
        return NextDoseEntry(date: now, content: .day(sample), showsNames: true)
    }

    func snapshot(for configuration: NoConfiguration, in context: Context) async -> NextDoseEntry {
        if context.isPreview { return placeholder(in: context) }
        return Self.timeline(at: Date()).entries.first!
    }

    func timeline(for configuration: NoConfiguration, in context: Context) async -> Timeline<NextDoseEntry> {
        Self.timeline(at: Date())
    }

    /// One entry for now, one at each open dose time of today, and one at the end of today with the first dose of
    /// tomorrow. So the widget moves to the next dose and to the next day with no reload. The next read is at midnight.
    /// A part of the day ends at `TodaySnapshot.expiresAt`, which can come before midnight, so the loop plans the same
    /// read again from that time.
    private static func timeline(at now: Date) -> Timeline<NextDoseEntry> {
        let showsNames = AppGroup.showsNames
        // A read-only read of one transaction, as in `DayProvider` (D048).
        guard let directory = AppGroup.databaseDirectory,
              let timeZone = NamedTimeZone(device: .current, at: now),
              let read = try? LocalStore.readForWidget(in: directory, at: now, deviceTimeZone: timeZone)
        else {
            // A locked iPhone, or a database that is not there. Try again soon. A launch of the app also reloads.
            return Timeline(
                entries: [NextDoseEntry(date: now, content: .unavailable, showsNames: showsNames)],
                policy: .after(now.addingTimeInterval(15 * 60))
            )
        }
        var entries: [NextDoseEntry] = []
        var start = now
        // Today in parts of at most 12 hours (`TodaySnapshot.longestAge`), then the first entry of tomorrow.
        for _ in 0..<4 {
            let day = NextDoseDay(TodaySnapshot(read, at: start, deviceTimeZone: timeZone))
            guard Calendar.current.isDate(start, inSameDayAs: now) else {
                entries.append(NextDoseEntry(date: start, content: .day(day), showsNames: showsNames))
                break
            }
            let times = day.open.map(\.plannedAt).filter { $0 > start && $0 < day.expiresAt }
            entries += ([start] + times).map { NextDoseEntry(date: $0, content: .day(day), showsNames: showsNames) }
            start = day.expiresAt
        }
        return Timeline(entries: entries, policy: .after(start))
    }
}

private struct NextDoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextDoseEntry

    var body: some View {
        content
            // The Lock Screen draws its own background.
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder private var content: some View {
        switch entry.content {
        case .unavailable:
            Text("Open Maru to update.")
                .font(.caption)
                .widgetURL(AppGroup.todayURL(nil))
        case let .day(day):
            let next = day.next(at: entry.date)
            Group {
                switch family {
                case .accessoryCircular:
                    circular(day, next)
                case .accessoryInline:
                    inline(day, next)
                default:
                    rectangular(day, next)
                }
            }
            .widgetURL(AppGroup.todayURL(next?.part))
        }
    }

    /// The names, or the number of doses when "Show Names in Reminders" is off (D029). At most three names, then the
    /// number of the other doses, as the Live Activity does (D110).
    private func doses(_ next: NextDoseDay.Time) -> String {
        guard entry.showsNames else {
            return String(localized: "\(next.names.count) doses", comment: "Next Dose widget and Live Activity: the number of doses in place of the names when \"Show Names in Reminders\" is off (D110, D113).")
        }
        let names = Array(next.names.prefix(3))
        let more = next.names.count - names.count
        guard more > 0 else { return names.formatted(.list(type: .and)) }
        return (names + [String(localized: "\(more) more", comment: "Next Dose widget and Live Activity: the last part of the list of names, for the doses after the first three names (D110, D113). Example: \"Vitamin D, Iron, Zinc, and 2 more\".")])
            .formatted(.list(type: .and))
    }

    private func time(_ next: NextDoseDay.Time, in day: NextDoseDay) -> String {
        next.plannedAt.formatted(.rowTime(in: day.timeZone))
    }

    /// The layout of the system Lock Screen widgets: a symbol and a bold first line, then plain lines (D094).
    @ViewBuilder
    private func rectangular(_ day: NextDoseDay, _ next: NextDoseDay.Time?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let next {
                HStack(spacing: 4) {
                    Image(systemName: "pills.fill").widgetAccentable()
                    Text(next.part.title)
                    Text(time(next, in: day))
                }
                .font(.headline)
                if next.plannedAt > entry.date {
                    Text("In \(Text(next.plannedAt, style: .relative))", comment: "Next Dose widget: the time left until the dose. Example: In 2 hr, 5 min (D113).")
                } else {
                    // No judgment: never "late" or "missed" (D101).
                    Text("Not recorded yet", comment: "Next Dose widget and Live Activity: the state after the planned time when the dose has no record. Calm, no judgment (D101, D110, D113).")
                }
                Text(doses(next))
            } else {
                HStack(spacing: 4) {
                    Image(systemName: day.total == 0 ? "pills.fill" : "checkmark.circle.fill").widgetAccentable()
                    if day.total == 0 {
                        Text("Nothing Planned Today")
                    } else {
                        Text("All done for today", comment: "Next Dose widget: every planned dose of today has a record. Calm (D101, D113).")
                    }
                }
                .font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    /// The progress of today as a ring, and the time of the next dose in it (D113).
    private func circular(_ day: NextDoseDay, _ next: NextDoseDay.Time?) -> some View {
        Gauge(value: Double(day.taken), in: 0...Double(max(day.total, 1))) {
            Image(systemName: "pills.fill")
        } currentValueLabel: {
            if let next {
                // No AM or PM, so the time fits in the ring. VoiceOver reads the full time.
                Text(next.plannedAt.formatted(
                    Date.FormatStyle(timeZone: day.timeZone).hour(.defaultDigits(amPM: .omitted)).minute()
                ))
                .accessibilityLabel(Text(time(next, in: day)))
            } else if day.total == 0 {
                Text(verbatim: "–")
            } else {
                Image(systemName: "checkmark")
                    .accessibilityLabel(Text("All done for today"))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(day.taken) of \(day.total) taken"))
    }

    @ViewBuilder
    private func inline(_ day: NextDoseDay, _ next: NextDoseDay.Time?) -> some View {
        if let next {
            Label {
                Text("\(time(next, in: day)), \(doses(next))")
            } icon: {
                Image(systemName: "pills.fill")
            }
        } else if day.total == 0 {
            Label("Nothing Planned Today", systemImage: "pills.fill")
        } else {
            Label("All done for today", systemImage: "checkmark.circle.fill")
        }
    }
}
