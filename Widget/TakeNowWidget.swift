import AppIntents
import MaruCore
import SwiftUI
import WidgetKit

/// "Record Dose": the doses of the current slot. A tap on a gray capsule records the dose (D048).
/// The capsule fills only after the app commits the record and the system loads the timeline again (spec 7.2).
struct TakeNowWidget: Widget {
    static let kind = "com.imhangli.maru.takeNow"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: NoConfiguration.self, provider: DayProvider()) { entry in
            TakeNowWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Record Dose")
        .description("Tap a capsule to record a dose of the current slot.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TakeNowWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        switch entry.content {
        case .unavailable:
            UnavailableView()
        case let .day(day):
            if let slot = day.slotAtClock(at: entry.date) {
                let limit = family == .systemMedium ? 4 : 2
                let shown = Self.pick(slot.doses, limit: limit)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(slot.part.title).foregroundStyle(entry.tint.tint)
                        Spacer()
                        if slot.doses.count > shown.count {
                            Text("+\(slot.doses.count - shown.count)").foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    if family == .systemMedium {
                        HStack(alignment: .top, spacing: 4) {
                            ForEach(shown) { dose in column(dose, epoch: day.epoch) }
                        }
                    } else {
                        ForEach(shown) { dose in row(dose, epoch: day.epoch) }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .widgetURL(AppGroup.todayURL(slot.part))
            } else {
                Text("Nothing Planned Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .widgetURL(AppGroup.todayURL(nil))
            }
        }
    }

    /// Open doses first, then taken ones, in the order of the slot.
    private static func pick(_ doses: [WidgetDay.Dose], limit: Int) -> [WidgetDay.Dose] {
        guard doses.count > limit else { return doses }
        let open = doses.filter(\.isOpen).prefix(limit)
        let rest = doses.filter { !$0.isOpen }.prefix(limit - open.count)
        let chosen = Set(open.map(\.id) + rest.map(\.id))
        return doses.filter { chosen.contains($0.id) }
    }

    private func row(_ dose: WidgetDay.Dose, epoch: Int) -> some View {
        HStack(spacing: 6) {
            control(dose, size: 30, epoch: epoch)
            VStack(alignment: .leading, spacing: 0) {
                Text(dose.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(dose.isTaken ? .secondary : .primary)
                    .lineLimit(1)
                if let amount = dose.amount {
                    Text(amount).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func column(_ dose: WidgetDay.Dose, epoch: Int) -> some View {
        VStack(spacing: 2) {
            control(dose, size: 44, epoch: epoch)
            Text(dose.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(dose.isTaken ? .secondary : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            if let amount = dose.amount {
                Text(amount).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// An open dose is a button. A taken or skipped dose is only a picture, and the widget has no undo.
    @ViewBuilder
    private func control(_ dose: WidgetDay.Dose, size: CGFloat, epoch: Int) -> some View {
        let mark = CapsuleMark(status: dose.status, tint: entry.tint.tint, size: size)
        if dose.isOpen {
            Button(intent: TakeDoseIntent(occurrenceID: dose.id, scheduleVersionID: dose.scheduleVersionID, epoch: epoch, readAt: dose.readAt)) {
                mark.frame(minWidth: 40, minHeight: 40)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Records this dose as taken"))
        } else {
            mark.frame(minWidth: 40, minHeight: 40)
        }
    }
}
