import MaruCore
import MaruDatabase
import UIKit

/// The text of a report that the user shares: the medication list, or the summary for a doctor (D091).
/// A report is a list of blocks of text. It holds what the user typed and counts of what the user recorded.
/// Maru makes it on the iPhone after a tap, and nothing leaves the iPhone except through the share sheet (spec 10).
struct ReportDocument {
    enum Style { case title, subtitle, heading, body, note }

    struct Block {
        let style: Style
        let text: String
    }

    var blocks: [Block] = []

    mutating func add(_ style: Style, _ text: String) {
        blocks.append(Block(style: style, text: text))
    }
}

/// Builds the two reports and writes a report as a PDF.
@MainActor
enum Report {
    /// The name, the form, the amount, the times, and the note of each active item, as the user typed them. It converts nothing.
    static func medicationList(_ rows: [(item: Item, schedule: Schedule?)], at now: Date) -> ReportDocument {
        var document = ReportDocument()
        document.add(.title, String(localized: "Medication List"))
        document.add(.subtitle, now.formatted(date: .long, time: .omitted))
        if rows.isEmpty { document.add(.body, String(localized: "No Items Yet")) }
        for (item, schedule) in rows {
            document.add(.heading, item.name)
            let version = schedule?.versions.last
            var facts: [String] = []
            if item.form != .unknown { facts.append(item.form.localizedName) }
            if let amount = version?.dose ?? item.asNeededDose { facts.append(amount.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
            if !facts.isEmpty { document.add(.body, facts.formatted(.list(type: .and, width: .narrow))) }
            if let version {
                let times = version.slotTimes.sorted { $0.time < $1.time }
                    .map { SchedulePreview.format(hour: $0.time.hour, minute: $0.time.minute) }
                    .formatted(.list(type: .and, width: .narrow))
                // The times and the days are on two lines, so they need no separator in any language.
                document.add(.body, times)
                document.add(.body, SchedulePreview.days(of: version))
            } else {
                document.add(.body, String(localized: "As Needed"))
            }
            switch item.intakeNote {
            case .preset(.withFood)?: document.add(.body, String(localized: "With food"))
            case .preset(.emptyStomach)?: document.add(.body, String(localized: "On an empty stomach"))
            case let .text(text)?: document.add(.body, text)
            case nil: break
            }
        }
        return document
    }

    /// For each item of the last `days` days, the planned doses, and how many are taken, skipped, and with no record.
    /// Numbers only: no percent, no streak, no score. The words say "No record", never "Missed" (spec 4).
    static func summary(_ read: HistorySummaryRead, days: Int, excluding: Set<ItemID>, today: LocalDate) -> ReportDocument {
        func day(_ date: LocalDate) -> String {
            date.noon.formatted(Date.FormatStyle.dateTime.year().month(.abbreviated).day().timeZone(.utc))
        }
        var document = ReportDocument()
        document.add(.title, String(localized: "Summary"))
        document.add(.subtitle, "\(day(today.adding(days: 1 - days))) – \(day(today))")
        let items = read.items
            .filter { read.summaries[$0.id] != nil && !excluding.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if items.isEmpty { document.add(.body, String(localized: "Nothing planned or recorded.")) }
        for item in items {
            guard let summary = read.summaries[item.id] else { continue }
            document.add(.heading, item.name)
            var counts: [String] = []
            if summary.planned > 0 {
                counts = [
                    String(localized: "Planned: \(summary.planned)"),
                    String(localized: "Taken: \(summary.taken)"),
                    String(localized: "Skipped: \(summary.skipped)"),
                    String(localized: "No record: \(summary.noRecord)"),
                ]
            }
            // Doses with no plan have their own count, so a dose never drops out.
            if summary.asNeededTaken > 0 {
                counts.append(String(localized: "As needed: \(summary.asNeededTaken)"))
            }
            // One count on each line, so the counts need no separator in any language.
            for count in counts { document.add(.body, count) }
        }
        document.add(
            .note,
            String(localized: "Dates use the time zone of this iPhone. No record means that nothing was recorded for a dose.")
        )
        return document
    }

    /// The PDF of a report. A4, or Letter for a region that uses inches. The text flows to a new page when a page is full.
    static func pdf(_ document: ReportDocument) -> Data {
        let page = Locale.current.measurementSystem == .us
            ? CGRect(x: 0, y: 0, width: 612, height: 792)
            : CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 54
        let text = NSMutableAttributedString()
        for (index, block) in document.blocks.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: "\n")) }
            text.append(NSAttributedString(string: block.text, attributes: attributes(of: block.style)))
        }
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let size = CGSize(width: page.width - 2 * margin, height: page.height - 2 * margin)
        var containers: [NSTextContainer] = []
        repeat {
            let container = NSTextContainer(size: size)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            containers.append(container)
            // Asking for the glyphs of the container lays out its text.
            _ = layout.glyphRange(for: container)
        } while NSMaxRange(layout.glyphRange(for: containers[containers.count - 1])) < layout.numberOfGlyphs && containers.count < 40
        let origin = CGPoint(x: margin, y: margin)
        return UIGraphicsPDFRenderer(bounds: page).pdfData { context in
            for container in containers {
                context.beginPage()
                let range = layout.glyphRange(for: container)
                layout.drawBackground(forGlyphRange: range, at: origin)
                layout.drawGlyphs(forGlyphRange: range, at: origin)
            }
        }
    }

    private static func attributes(of style: ReportDocument.Style) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        let font: UIFont
        var color = UIColor.black
        switch style {
        case .title:
            font = .systemFont(ofSize: 24, weight: .bold)
            paragraph.paragraphSpacing = 2
        case .subtitle:
            font = .systemFont(ofSize: 13)
            color = .darkGray
            paragraph.paragraphSpacing = 14
        case .heading:
            font = .systemFont(ofSize: 15, weight: .semibold)
            paragraph.paragraphSpacingBefore = 8
        case .body:
            font = .systemFont(ofSize: 12)
        case .note:
            font = .systemFont(ofSize: 10)
            color = .darkGray
            paragraph.paragraphSpacingBefore = 16
        }
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }
}
