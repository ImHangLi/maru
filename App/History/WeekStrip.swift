import MaruCore
import SwiftUI

extension HistoryItemWeek {
    /// The VoiceOver summary of the strip, and the line under it in the item detail (D054, D057).
    var summary: String {
        if countedDays == marks.count { return String(localized: "Taken on \(takenDays) of the last 7 days") }
        return String(localized: "All doses taken on \(takenDays) of \(countedDays) planned days")
    }
}

/// 7 small capsules, the oldest day first (D054). The History rows and the item detail share it (D057).
/// Filled: every planned dose taken, or an as-needed dose taken. Filled at 40%: some doses taken. Outline: planned, and none taken. An empty slot of the same width: nothing planned.
/// A capsule that changes after a record uses the state motion, which keeps its fade with Reduce Motion.
struct WeekStrip: View {
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
