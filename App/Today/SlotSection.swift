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

/// The name of a part of the day, in the text color (D050). With two or more open rows the header has
/// "Record All" (D021).
private struct SlotHeader: View {
    @Environment(AppModel.self) private var model
    let group: TodaySnapshot.Group

    var body: some View {
        // At the accessibility sizes the button goes under the title, so the title keeps its width.
        ViewThatFits(in: .horizontal) {
            HStack { content }
            VStack(alignment: .leading) { content }
        }
        .textCase(nil)
        // "Record All" comes and goes in place, after the commit (spec 7.2, D030).
        .motion(.state, value: recordAllCount >= 2)
    }

    @ViewBuilder private var content: some View {
        title.accessibilityAddTraits(.isHeader)
        Spacer(minLength: 0)
        if recordAllCount >= 2 {
            Button("Record All") { model.recordAll(group) }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                // Each section has this button, so the label names the part (D021).
                .accessibilityLabel(Text("Record all \(recordAllCount) in \(String(localized: group.part.title)) as taken"))
        }
    }

    /// Rows with an unsaved event offer only their own retry, so the button leaves them out.
    private var recordAllCount: Int {
        group.openEntries.filter { model.today.pending[$0.id] == nil }.count
    }

    private var title: some View {
        Text(group.part.title).foregroundStyle(.primary)
    }
}
