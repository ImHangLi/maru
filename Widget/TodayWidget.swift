import MaruCore
import SwiftUI
import WidgetKit

/// "Today": counts and capsules, no names, no buttons. A tap opens Today at the slot (D048).
struct TodayWidget: Widget {
    static let kind = "com.imhangli.maru.today"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NoConfiguration.self, provider: DayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Today")
        .description("See how many doses are left. It shows no names.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        switch entry.content {
        case .unavailable:
            UnavailableView()
        case let .day(day) where day.doses.isEmpty:
            Text("Nothing to Take Today")
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
                }
            }
            .font(.largeTitle.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            Spacer(minLength: 4)
            HStack {
                Spacer(minLength: 0)
                CapsuleRows(
                    taken: Array((slot?.doses ?? day.doses).prefix(8)).map(\.isTaken),
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
        HStack(spacing: 4) {
            if let slot {
                Text(slot.part.title).foregroundStyle(tint)
                Text(verbatim: "·").foregroundStyle(.secondary)
                Text(slot.time.formatted(.rowTime(in: day.timeZone))).foregroundStyle(.secondary)
            } else {
                Text("All done").foregroundStyle(tint)
                if let next = day.nextTime {
                    Text(verbatim: "·").foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                Text("\(day.takenCount) of \(day.doses.count)").font(.headline).foregroundStyle(.secondary)
            }
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
                                taken: slot.doses.prefix(6).map(\.isTaken),
                                tint: tint, size: 26, perRow: 3, alignment: .leading
                            )
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(AppGroup.todayURL(nil))
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
