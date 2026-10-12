import MaruCore
import SwiftUI

/// One list section per part of the day. The header is the name of the part, not a clock time (D011).
/// A finished section folds after a launch or a return to the app, and a short time after the record that
/// finishes it. A tap on its header opens or folds it (D012, D028).
struct SlotSection: View {
    @Environment(AppModel.self) private var model
    let group: TodaySnapshot.Group
    let timeZone: TimeZone

    var body: some View {
        let isFolded = model.isFolded(group)
        Section {
            if !isFolded {
                ForEach(group.entries) { TodayRow(entry: $0, timeZone: timeZone) }
            }
        } header: {
            SlotHeader(group: group, isFolded: isFolded)
        }
    }
}

/// The name of a part of the day, in the text color (D050). With two or more open rows the header has
/// "Record All" (D021). The header of a finished part folds and opens the section. It has no chevron (D050).
private struct SlotHeader: View {
    @Environment(AppModel.self) private var model
    let group: TodaySnapshot.Group
    let isFolded: Bool

    var body: some View {
        // At the accessibility sizes the button goes under the title, so the title keeps its width.
        ViewThatFits(in: .horizontal) {
            HStack { content }
            VStack(alignment: .leading) { content }
        }
        .textCase(nil)
        // "Record All" comes and goes in place, after the commit (spec 7.2, D030).
        .motion(.state, value: [model.isFinished(group), recordAllCount >= 2])
    }

    @ViewBuilder private var content: some View {
        if model.isFinished(group) {
            // Only a finished part folds, so only its header is a button. With Reduce Motion it changes at once (spec 5.3).
            Button {
                withMotion(.layout) { model.toggleFold(group) }
            } label: {
                HStack {
                    title
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(group.part.title))
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(Text("All recorded"))
            .accessibilityHint(isFolded ? Text("Shows the items.") : Text("Hides the items."))
        } else {
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
    }

    /// Rows with an unsaved event offer only their own retry, so the button leaves them out.
    private var recordAllCount: Int {
        group.openEntries.filter { model.today.pending[$0.id] == nil }.count
    }

    private var title: some View {
        Text(group.part.title).foregroundStyle(.primary)
    }
}
