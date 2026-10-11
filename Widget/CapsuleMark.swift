import SwiftUI

/// One dose, as a capsule tilted by 45 degrees, like the app icon (D048). It fills a square of `size` points.
///
/// Taken: filled with the app tint as a gradient. Not taken: light gray with a thin gray edge.
/// The state is never only a color: the widgets also give a VoiceOver label.
struct CapsuleMark: View {
    let isTaken: Bool
    let tint: Color
    let size: CGFloat

    var body: some View {
        // A capsule of length 0.9 and width 0.5 of the square has a diagonal of exactly the square.
        let shape = Capsule()
        ZStack {
            if isTaken {
                shape.fill(tint)
                shape.fill(LinearGradient(
                    colors: [.white.opacity(0.32), .white.opacity(0)], startPoint: .top, endPoint: .bottom
                ))
            } else {
                shape.fill(Color(.systemGray5))
                shape.strokeBorder(Color(.systemGray3), lineWidth: max(1, size / 24))
            }
        }
        .frame(width: size * 0.9, height: size * 0.5)
        .rotationEffect(.degrees(-45))
        .frame(width: size, height: size)
        .accessibilityLabel(isTaken ? Text("Taken") : Text("Not taken"))
    }
}

/// The capsules of a slot in rows that fill from the trailing edge, as many as the width gives.
struct CapsuleRows: View {
    let taken: [Bool]
    let tint: Color
    let size: CGFloat
    let perRow: Int
    let alignment: HorizontalAlignment

    var body: some View {
        let rows = stride(from: 0, to: taken.count, by: perRow).map { Array(taken[$0..<min($0 + perRow, taken.count)]) }
        VStack(alignment: alignment, spacing: 2) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(rows[row].indices, id: \.self) { index in
                        CapsuleMark(isTaken: rows[row][index], tint: tint, size: size)
                    }
                }
            }
        }
    }
}
