import MaruCore
import SwiftUI
import UIKit

/// The graph at the top of the history page (D041): one square for each day, one column for each week,
/// and one row for each weekday. The app tint in three levels shows the share of the planned doses that are
/// taken. The graph has no title, no legend, and no count.
///
/// A kept custom control (D026): SwiftUI has no heat map. One `Canvas` draws the squares and the labels. A tap
/// selects a day, and a short press starts a drag across the days. The graph is the first section of the list
/// and scrolls with it, so a swipe that starts on the graph scrolls the page (D109). The end of a touch opens
/// the log of the selected day (D054).
struct HistoryGraphView: View {
    let graph: HistoryGraph
    let counts: [LocalDate: HistoryDayCount]
    @Binding var selection: LocalDate?
    /// The end of a touch, or the default action of VoiceOver. The log of the selected day opens then.
    let onCommit: () -> Void

    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption2) private var labelHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var letterWidth: CGFloat = 10

    var body: some View {
        GraphFrame(graph: graph, metrics: metrics) {
            GeometryReader { proxy in
                let layout = HistoryGraphLayout(graph: graph, width: proxy.size.width, metrics: metrics)
                // The canvas is a little larger than the graph, so the ring of a square at the edge shows whole.
                let outset = HistoryGraphLayout.ringOutset
                Canvas { context, _ in
                    context.translateBy(x: outset, y: outset)
                    draw(in: &context, layout: layout)
                }
                .padding(-outset)
                .overlay {
                    GraphTouch { point, isEnd in
                        selection = day(at: point, in: layout, outset: outset)
                        if isEnd { onCommit() }
                    } onCancel: {
                        selection = nil
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: Tile.shape)
        // A light tick when the finger reaches another day. A clear gives none.
        .sensoryFeedback(.selection, trigger: selection) { _, new in new != nil }
        .accessibilityElement()
        .accessibilityLabel(Text("Doses taken each day"))
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            // The first step selects today. The default action opens the log of the selected day.
            let day = selection.map { $0.adding(days: direction == .increment ? 1 : -1) } ?? graph.today
            selection = min(max(day, firstShown), graph.today)
        }
        .accessibilityAction {
            if selection != nil { onCommit() }
        }
    }

    private var metrics: HistoryGraphLayout.Metrics {
        // The squares keep their size at every text size. The labels grow, so the weekday letters go
        // at the accessibility sizes, where they would overlap.
        let letters = graph.weeks == HistoryGraph.steps[0] && !typeSize.isAccessibilitySize
        return HistoryGraphLayout.Metrics(labelHeight: labelHeight, letterWidth: letters ? letterWidth : 0)
    }

    private var firstShown: LocalDate { max(graph.firstDay, graph.start) }

    // MARK: Touch

    /// The nearest day to a point of the canvas, so the finger does not need to hit a square. A day that is not
    /// here yet gives today.
    private func day(at point: CGPoint, in layout: HistoryGraphLayout, outset: CGFloat) -> LocalDate {
        let cell = layout.nearestCell(to: CGPoint(x: point.x - outset, y: point.y - outset))
        return min(max(graph.date(column: cell.column, row: cell.row), firstShown), graph.today)
    }

    // MARK: Drawing

    private func draw(in context: inout GraphicsContext, layout: HistoryGraphLayout) {
        let future = Color(.tertiarySystemFill)
        for column in 0..<graph.weeks {
            for row in 0..<7 {
                let date = graph.date(column: column, row: row)
                let rect = layout.cellRect(column: column, row: row)
                if date > graph.today {
                    // A day that is not here yet: a faint outline, even like dot paper.
                    let outline = rect.insetBy(dx: 0.5, dy: 0.5)
                    context.stroke(layout.square(outline), with: .color(future), lineWidth: 1)
                } else if graph.isShown(date) {
                    context.fill(layout.square(rect), with: .color(fill(for: counts[date])))
                }
            }
        }
        if let selection, graph.isShown(selection) {
            // A thin ring in the tint with a small gap, and no dark border.
            let cell = graph.cell(of: selection)
            let inset = HistoryGraphLayout.ringWidth / 2 - HistoryGraphLayout.ringOutset
            let ring = layout.cellRect(column: cell.column, row: cell.row).insetBy(dx: inset, dy: inset)
            context.stroke(layout.square(ring), with: .color(appColor.tint), lineWidth: HistoryGraphLayout.ringWidth)
        }
        drawLabels(in: &context, layout: layout)
    }

    /// The level of a day. Three steps of the tint for the share taken. A planned day with nothing taken is a
    /// quiet neutral, and a day with nothing planned is a fainter neutral, so it does not look like a miss.
    private func fill(for count: HistoryDayCount?) -> Color {
        guard let count, count.scheduled > 0 else { return Color(.quaternarySystemFill) }
        switch HistoryGraphLevel(taken: count.taken, scheduled: count.scheduled) {
        case .noneTaken: return Color(.tertiarySystemFill)
        case .someTaken: return appColor.tint.opacity(0.3)
        case .mostTaken: return appColor.tint.opacity(0.6)
        case .allTaken: return appColor.tint
        }
    }

    private func drawLabels(in context: inout GraphicsContext, layout: HistoryGraphLayout) {
        var selected: (band: Int, frame: CGRect)?
        if let selection, graph.isShown(selection) {
            let cell = graph.cell(of: selection)
            let text = context.resolve(
                Text(selection.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            )
            let size = text.measure(in: CGSize(width: layout.width, height: .infinity))
            let center = layout.cellRect(column: cell.column, row: 0).midX
            let x = min(max(center - size.width / 2, 0), layout.width - size.width)
            let frame = CGRect(x: x, y: layout.labelTop(band: layout.band(of: cell.column)), width: size.width, height: size.height)
            context.draw(text, in: frame)
            selected = (layout.band(of: cell.column), frame)
        }
        for band in 0..<layout.bands {
            // A month label that would touch the one before it, or the date of the selection, does not show.
            var end = -CGFloat.infinity
            for label in graph.monthLabels(columns: layout.columns(of: band)) {
                let text = context.resolve(
                    Text(label.month.noon.formatted(Date.FormatStyle.dateTime.month(.abbreviated).timeZone(.utc)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                )
                let size = text.measure(in: CGSize(width: layout.width, height: .infinity))
                let x = layout.cellRect(column: label.column, row: 0).minX
                let frame = CGRect(x: x, y: layout.labelTop(band: band), width: size.width, height: size.height)
                let space = HistoryGraphLayout.labelSpace
                guard frame.minX >= end + space, frame.maxX <= layout.width else { continue }
                if let selected, selected.band == band, frame.insetBy(dx: -space, dy: 0).intersects(selected.frame) { continue }
                context.draw(text, in: frame)
                end = frame.maxX
            }
        }
        guard layout.metrics.letterWidth > 0 else { return }
        // Only Monday, Wednesday, and Friday, as in the GitHub graph. They are every second row.
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        for row in 0..<7 {
            let weekday = graph.date(column: 0, row: row).weekday
            guard [.monday, .wednesday, .friday].contains(weekday) else { continue }
            let text = context.resolve(Text(symbols[weekday.rawValue % 7]).font(.caption2).foregroundStyle(.secondary))
            context.draw(text, at: CGPoint(x: 0, y: layout.cellRect(column: 0, row: row).midY), anchor: .leading)
        }
    }

    // MARK: VoiceOver

    private var accessibilityValue: Text {
        if let selection, graph.isShown(selection) {
            let date = selection.noon.formatted(Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day().timeZone(.utc))
            guard let count = counts[selection] else { return Text("\(date), nothing planned") }
            return Text("\(date), \(count.taken) of \(count.scheduled) taken")
        }
        let shown = (0...graph.today.days(since: firstShown)).map { firstShown.adding(days: $0) }
        let levels = shown.compactMap { counts[$0] }.map { HistoryGraphLevel(taken: $0.taken, scheduled: $0.scheduled) }
        let start = firstShown.noon.formatted(Date.FormatStyle.dateTime.month(.wide).day().timeZone(.utc))
        func days(_ level: HistoryGraphLevel) -> Int { levels.filter { $0 == level }.count }
        return Text(
            "Since \(start). Days with all taken: \(days(.allTaken)). Most: \(days(.mostTaken)). Some: \(days(.someTaken)). None: \(days(.noneTaken))."
        )
    }
}

/// The level of a day with a plan, by the share of its planned doses that are taken (D041).
/// "Some" is half or less, "most" is more than half, and "all" is every dose. A skipped dose is not taken.
enum HistoryGraphLevel: Equatable {
    case noneTaken, someTaken, mostTaken, allTaken

    init(taken: Int, scheduled: Int) {
        if taken >= scheduled {
            self = .allTaken
        } else if taken == 0 {
            self = .noneTaken
        } else {
            self = taken * 2 > scheduled ? .mostTaken : .someTaken
        }
    }
}

/// The geometry of the graph in points, for one width. Pure, so the numbers can be checked by hand (D041).
///
/// The graph fills the width of the card. One band holds 13 or 26 columns, and 52 weeks are two bands of 26,
/// the older band above. The gap is a fixed share of the side, so a square has the same shape at each step.
struct HistoryGraphLayout {
    struct Metrics: Equatable {
        /// The height of the month label row. It follows the text size.
        var labelHeight: CGFloat
        /// The width of the weekday letters at the left. 0 when they do not show.
        var letterWidth: CGFloat
    }

    static let cornerRatio: CGFloat = 0.22
    static let labelSpacing: CGFloat = 4
    static let letterSpacing: CGFloat = 4
    static let bandSpacing: CGFloat = 12
    static let labelSpace: CGFloat = 4
    static let ringWidth: CGFloat = 1.5
    static let ringGap: CGFloat = 1
    /// How far the ring reaches out of its square.
    static let ringOutset = ringGap + ringWidth

    let graph: HistoryGraph
    let width: CGFloat
    let metrics: Metrics

    var bands: Int { graph.weeks > 26 ? 2 : 1 }
    var columnsPerBand: Int { graph.weeks / bands }
    /// The gap as a share of the side: 0.19 for 13 columns, 0.3 for 26.
    var gapRatio: CGFloat { columnsPerBand > 13 ? 0.3 : 0.19 }
    var leading: CGFloat { metrics.letterWidth > 0 ? metrics.letterWidth + Self.letterSpacing : 0 }
    var side: CGFloat {
        max(0, (width - leading) / (CGFloat(columnsPerBand) + CGFloat(columnsPerBand - 1) * gapRatio))
    }
    var gap: CGFloat { side * gapRatio }
    var pitch: CGFloat { side + gap }
    var bandHeight: CGFloat { metrics.labelHeight + Self.labelSpacing + 7 * side + 6 * gap }
    var height: CGFloat { CGFloat(bands) * bandHeight + CGFloat(bands - 1) * Self.bandSpacing }

    func band(of column: Int) -> Int { column / columnsPerBand }

    func columns(of band: Int) -> Range<Int> { band * columnsPerBand..<(band + 1) * columnsPerBand }

    func labelTop(band: Int) -> CGFloat { CGFloat(band) * (bandHeight + Self.bandSpacing) }

    func squaresTop(band: Int) -> CGFloat { labelTop(band: band) + metrics.labelHeight + Self.labelSpacing }

    func cellRect(column: Int, row: Int) -> CGRect {
        CGRect(
            x: leading + CGFloat(column % columnsPerBand) * pitch,
            y: squaresTop(band: band(of: column)) + CGFloat(row) * pitch,
            width: side,
            height: side
        )
    }

    func square(_ rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: rect.width * Self.cornerRatio, style: .continuous)
    }

    /// The cell nearest to a point, also a point between two squares or outside the graph.
    func nearestCell(to point: CGPoint) -> (column: Int, row: Int) {
        let band = bands == 2 && point.y > labelTop(band: 1) - Self.bandSpacing / 2 ? 1 : 0
        // At width 0 there is no square to choose. A division by zero would trap in the conversion to Int.
        guard pitch > 0 else { return (band * columnsPerBand, 0) }
        let local = Int(((point.x - leading - side / 2) / pitch).rounded())
        let row = Int(((point.y - squaresTop(band: band) - side / 2) / pitch).rounded())
        return (band * columnsPerBand + min(max(local, 0), columnsPerBand - 1), min(max(row, 0), 6))
    }
}

/// The touch of the graph (D109). A tap selects the day under the finger. A press of 0.2 seconds selects it too,
/// and a drag after the press moves the selection. The end of either touch opens the log of the day.
///
/// UIKit recognizers, not SwiftUI gestures: in the list, a UIKit tap and long press share a touch with the
/// scroll of the list in the same way on iOS 17, 18, and 26. A finger that moves before the press time scrolls
/// the page, and the press fails. A press that starts first stops the scroll until the finger lifts.
private struct GraphTouch: UIViewRepresentable {
    /// A point in the canvas, and true at the end of the touch.
    let onTouch: (CGPoint, Bool) -> Void
    /// The system cancelled a press, for example for a call. No log opens.
    let onCancel: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let coordinator = context.coordinator
        view.addGestureRecognizer(UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tap)))
        let press = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.press))
        press.minimumPressDuration = 0.2
        view.addGestureRecognizer(press)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.touch = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(touch: self) }

    @MainActor
    final class Coordinator: NSObject {
        var touch: GraphTouch

        init(touch: GraphTouch) { self.touch = touch }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            touch.onTouch(recognizer.location(in: recognizer.view), true)
        }

        @objc func press(_ recognizer: UILongPressGestureRecognizer) {
            let point = recognizer.location(in: recognizer.view)
            switch recognizer.state {
            case .began, .changed: touch.onTouch(point, false)
            case .ended: touch.onTouch(point, true)
            default: touch.onCancel()
            }
        }
    }
}

/// Gives the canvas the full width and the height that the layout needs for it.
private struct GraphFrame: Layout {
    let graph: HistoryGraph
    let metrics: HistoryGraphLayout.Metrics

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return CGSize(width: width, height: HistoryGraphLayout(graph: graph, width: width, metrics: metrics).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}
