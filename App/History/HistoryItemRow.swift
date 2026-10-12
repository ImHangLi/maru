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
        .accessibilityValue(Text(verbatim: "\(subtitle). \(week.summary)"))
    }

    private func strip(_ look: TodaySnapshot.ItemLook?) -> some View {
        WeekStrip(marks: week.marks, color: look?.color.color ?? .accentColor)
    }

    /// The parts of the day of the planned doses, for example "Morning and Evening", or "As Needed".
    private var subtitle: String {
        if week.isAsNeeded { return String(localized: "As Needed") }
        return week.dayParts.map { String(localized: $0.title) }.formatted(.list(type: .and))
    }
}
