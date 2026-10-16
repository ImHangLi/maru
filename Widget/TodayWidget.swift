import MaruCore
import SwiftUI
import WidgetKit

/// "Today": counts, a progress bar, and capsules, no names, no buttons. A tap opens Today at the slot (D048).
struct TodayWidget: Widget {
    static let kind = "com.imhangli.maru.today"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NoConfiguration.self, provider: DayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today")
        .description("See how many doses are left. It shows no names.")
        // The two Lock Screen families show the next part of the day and the progress, and no names (D091).
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    private var isLockScreen: Bool {
        family == .accessoryCircular || family == .accessoryRectangular
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
        case let .day(day) where isLockScreen:
            LockScreenToday(day: day, date: entry.date, isCircular: family == .accessoryCircular)
        case let .day(day) where day.doses.isEmpty:
            Text("Nothing Planned Today")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetURL(AppGroup.todayURL(nil))
        case let .day(day):
            if family == .systemMedium {
                MediumToday(day: day, date: entry.date, tint: entry.tint.tint)
            } else {
                SmallToday(day: day, date: entry.date, tint: entry.tint.tint)
            }
        }
    }
}

/// The Lock Screen widget (D091): the progress of today as a gauge, and in the wide form the next part of the day with
/// the number of open doses. It shows no names, like the other "Today" widgets (D048). A tap opens Today at the slot.
private struct LockScreenToday: View {
    let day: WidgetDay
    let date: Date
    let isCircular: Bool

    var body: some View {
        let slot = day.slotWithOpenDose(at: date)
        let total = day.doses.count
        Group {
            if isCircular {
                Gauge(value: Double(day.takenCount), in: 0...Double(max(total, 1))) {
                    Text("Today")
                } currentValueLabel: {
                    Text(verbatim: total == 0 ? "–" : "\(day.takenCount)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                // The layout of the system Lock Screen widgets, such as Batteries: a symbol and a bold first line,
                // one plain line, and a bar with no label (D094).
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "pills.fill").widgetAccentable()
                        if total == 0 {
                            Text("Nothing Planned Today")
                        } else if let slot {
                            Text(slot.part.title)
                            Text(slot.time.formatted(.rowTime(in: day.timeZone)))
                        } else {
                            Text("All done")
                        }
                    }
                    .font(.headline)
                    if let slot {
                        Text("\(slot.openCount) left")
                    } else if total > 0, let next = day.nextTime {
                        Text("Next \(next.formatted(.rowTime(in: day.timeZone)))")
                    }
                    if total > 0 {
                        Gauge(value: Double(day.takenCount), in: 0...Double(total)) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                            .labelsHidden()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .widgetURL(AppGroup.todayURL(slot?.part))
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(day.takenCount) of \(total) taken"))
    }
}

private struct SmallToday: View {
    let day: WidgetDay
    let date: Date
    let tint: Color

    var body: some View {
        let slot = day.slotWithOpenDose(at: date)
        VStack(alignment: .leading, spacing: 0) {
            header(slot)
            Spacer(minLength: 4)
            Group {
                if let slot {
                    Text("\(slot.openCount) left")
                } else {
                    Text("\(day.takenCount) of \(day.doses.count)")
                        .accessibilityLabel(Text("\(day.takenCount) of \(day.doses.count) taken"))
                }
            }
            .font(.largeTitle.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            HStack {
                Spacer(minLength: 0)
                CapsuleRows(
                    statuses: Array((slot?.doses ?? day.doses).prefix(8)).map(\.status),
                    tint: tint, size: 28, perRow: 4, alignment: .trailing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(AppGroup.todayURL(slot?.part))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func header(_ slot: WidgetDay.Slot?) -> some View {
        HStack(spacing: 6) {
            if let slot {
                Text(slot.part.title).foregroundStyle(tint)
                Text(slot.time.formatted(.rowTime(in: day.timeZone))).foregroundStyle(.secondary)
            } else {
                Text("All done").foregroundStyle(tint)
                if let next = day.nextTime {
                    Text("Next \(next.formatted(.rowTime(in: day.timeZone)))").foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct MediumToday: View {
    let day: WidgetDay
    let date: Date
    let tint: Color

    var body: some View {
        let current = day.slotAtClock(at: date)?.part
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // The bar says "Today" and the count to VoiceOver.
                Text("Today").font(.headline).accessibilityHidden(true)
                Spacer()
                DayProgressBar(taken: day.takenCount, total: day.doses.count, tint: tint)
            }
            // The columns end at the bottom edge, so the space over the title equals the space under the capsules.
            Spacer(minLength: 10)
            HStack(alignment: .top, spacing: 8) {
                ForEach(day.slots) { slot in
                    Link(destination: AppGroup.todayURL(slot.part)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slot.part.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(slot.part == current ? tint : .primary)
                            Text(slot.time.formatted(.rowTime(in: day.timeZone)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            CapsuleRows(
                                statuses: slot.doses.prefix(6).map(\.status),
                                tint: tint, size: 26, perRow: 3, alignment: .leading
                            )
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(AppGroup.todayURL(nil))
    }
}

/// The share of the doses of today that are taken, as one bar with no text (D076).
///
/// The track is the system fill, a gray with an alpha value, so it stays quiet in the light, dark, tinted, and
/// clear looks. The fill is the app tint, and it takes the accent of a tinted Home Screen. VoiceOver reads the count.
private struct DayProgressBar: View {
    let taken: Int
    let total: Int
    let tint: Color

    private let width: CGFloat = 96
    private let height: CGFloat = 8

    var body: some View {
        Capsule()
            .fill(Color(.systemFill))
            .frame(width: width, height: height)
            .overlay(alignment: .leading) {
                if taken > 0, total > 0 {
                    // At least a circle, so one taken dose of many shows.
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, width * CGFloat(taken) / CGFloat(total)), height: height)
                        .widgetAccentable()
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Today"))
            .accessibilityValue(Text("\(taken) of \(total) taken"))
    }
}

struct UnavailableView: View {
    var body: some View {
        Text("Open Maru to update.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .widgetURL(AppGroup.todayURL(nil))
    }
}
