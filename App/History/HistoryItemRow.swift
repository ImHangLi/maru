import MaruCore
import SwiftUI

/// One row of "Last 7 Days" (D054): the form icon in the item color, the name, the part of the day or
/// "As needed" under it, and a strip of 7 small capsules at the end. The strip runs from the oldest day at the
/// left to today at the right. A tap opens the log of the item.
struct HistoryItemRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let week: HistoryItemWeek

    var body: some View {
        let look = model.history.looks[week.itemID]
        let name = look?.name ?? ""
        NavigationLink {
            HistoryLogView(scope: .item(week.itemID))
        } label: {
            HStack(spacing: 12) {
                if let look {
                    FormIcon(form: look.form, color: look.color)
                        .frame(minWidth: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    // Names wrap and never truncate (spec 5.3).
                    Text(verbatim: name)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    // At the accessibility sizes the strip goes under the words, so the name keeps its width.
                    if typeSize.isAccessibilitySize { strip(look) }
                }
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !typeSize.isAccessibilitySize { strip(look) }
            }
            .frame(minHeight: 44)
        }
        // The strip says nothing to VoiceOver, so the row reads a summary.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: "\(subtitle). \(summary)"))
    }

    private func strip(_ look: TodaySnapshot.ItemLook?) -> some View {
        WeekStrip(marks: week.marks, color: look?.color.color ?? .accentColor)
    }

    /// The parts of the day of the planned doses, for example "Morning and Evening", or "As Needed".
    private var subtitle: String {
        if week.isAsNeeded { return String(localized: "As Needed") }
        return week.dayParts.map { String(localized: $0.title) }.formatted(.list(type: .and))
    }

    private var summary: String {
        let taken = week.takenDays
        let counted = week.countedDays
        if counted == week.marks.count { return String(localized: "Taken on \(taken) of the last 7 days") }
        return String(localized: "All doses taken on \(taken) of \(counted) planned days")
    }
}

/// 7 small capsules, the oldest day first (D054). Filled: every planned dose taken, or an as-needed dose taken.
/// Filled at 40%: some doses taken. Outline: planned, and none taken. An empty slot of the same width: nothing planned.
/// A capsule that changes after a record uses the state motion, which keeps its fade with Reduce Motion.
private struct WeekStrip: View {
    let marks: [HistoryDayMark]
    let color: Color
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 16

    var body: some View {
        HStack(spacing: height * 0.2) {
            ForEach(marks.indices, id: \.self) { capsule(marks[$0]) }
        }
        .motion(.state, value: marks)
        .accessibilityHidden(true)
    }

    /// Both layers stay in the tree, so a change of the mark fades and never jumps.
    private func capsule(_ mark: HistoryDayMark) -> some View {
        ZStack {
            Capsule().fill(color).opacity(mark == .all ? 1 : mark == .some ? 0.4 : 0)
            Capsule().strokeBorder(color, lineWidth: 1.5).opacity(mark == .missed ? 1 : 0)
        }
        .frame(width: height * 0.4, height: height)
    }
}
