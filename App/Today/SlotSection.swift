import MaruCore
import SwiftUI

/// One list section per part of the day. The header is the name of the part, not a clock time (D011).
/// The section always shows its rows, also when every row is done (D057).
struct SlotSection: View {
    let group: TodaySnapshot.Group
    let timeZone: TimeZone

    var body: some View {
        Section {
            ForEach(group.entries) { TodayRow(entry: $0, timeZone: timeZone) }
        } header: {
            SlotHeader(group: group)
        }
    }
}

/// The name of a part of the day, in the text color (D050). It has no button (D060).
private struct SlotHeader: View {
    let group: TodaySnapshot.Group

    var body: some View {
        Text(group.part.title)
            .foregroundStyle(.primary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}
