import MaruCore
import SwiftUI

/// One dose, as a capsule tilted by 45 degrees, like the app icon (D048). It fills a square of `size` points.
///
/// Taken: filled with the app tint as a gradient. Open or skipped: light gray with a thin gray edge.
/// On the Watch, a skipped capsule also has a minus along its axis, as the row on the iPhone has.
/// The state is never only a color: the widgets also give a VoiceOver label.
/// The Watch app draws the same mark (D065). watchOS has no `systemGray5` and `systemGray3`, so it uses grays
/// of the same strength on its black background.
struct CapsuleMark: View {
    let status: OccurrenceStatus
    let tint: Color
    let size: CGFloat

    var body: some View {
        // A capsule of length 0.9 and width 0.5 of the square has a diagonal of exactly the square.
        let shape = Capsule()
        ZStack {
            if status == .taken {
                shape.fill(tint)
                shape.fill(LinearGradient(
                    colors: [.white.opacity(0.32), .white.opacity(0)], startPoint: .top, endPoint: .bottom
                ))
            } else {
                #if os(watchOS)
                shape.fill(Color(white: 0.17))
                shape.strokeBorder(Color(white: 0.28), lineWidth: max(1, size / 24))
                if status == .skipped {
                    // The minus of a skipped row on the iPhone, so a skipped dose does not look open.
                    Capsule()
                        .fill(.secondary)
                        .frame(width: size * 0.4, height: max(2, size / 12))
                }
                #else
                shape.fill(Color(.systemGray5))
                shape.strokeBorder(Color(.systemGray3), lineWidth: max(1, size / 24))
                #endif
            }
        }
        .frame(width: size * 0.9, height: size * 0.5)
        .rotationEffect(.degrees(-45))
        .frame(width: size, height: size)
        .accessibilityLabel(label)
    }

    private var label: Text {
        switch status {
        case .taken: Text("Taken")
        case .skipped: Text("Skipped")
        case .unrecorded: Text("Not recorded")
        }
    }
}

/// The capsules of a slot in rows that fill from the trailing edge, as many as the width gives.
struct CapsuleRows: View {
    let statuses: [OccurrenceStatus]
    let tint: Color
    let size: CGFloat
    let perRow: Int
    let alignment: HorizontalAlignment

    var body: some View {
        let rows = stride(from: 0, to: statuses.count, by: perRow).map { Array(statuses[$0..<min($0 + perRow, statuses.count)]) }
        VStack(alignment: alignment, spacing: 2) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(rows[row].indices, id: \.self) { index in
                        CapsuleMark(status: rows[row][index], tint: tint, size: size)
                    }
                }
            }
        }
    }
}
