import Foundation

/// The counts of one item over a range of days (D091, R5). The item detail and the summary for a doctor use it.
/// It holds numbers only: no percent, no streak, no score (spec 1).
public struct ItemSummary: Hashable, Sendable {
    public let itemID: ItemID
    /// The planned doses that count: `taken + skipped + noRecord`. A dose of today that is not due yet does not count.
    public var planned: Int { taken + skipped + noRecord }
    /// The planned doses with a taken record.
    public var taken = 0
    /// The planned doses with a skipped record.
    public var skipped = 0
    /// The planned doses that count and have no record, or a record that the user took back.
    public var noRecord = 0
    /// The as-needed doses with a taken record. They have no plan, so `planned` does not count them.
    public var asNeededTaken = 0

    public init(itemID: ItemID) {
        self.itemID = itemID
    }
}

extension History {
    /// One count for each item that has a counted dose or a taken as-needed dose in `days`.
    ///
    /// `days` has the rules of `days(_:items:schedules:stored:asNeeded:deviceTimeZone:)`, so a count agrees with the
    /// timeline. A planned dose counts by `isCounted`, the same rule as the week strip and the graph (R5).
    /// The caller chooses the range by the days that it passes.
    public static func summary(days: [HistoryDay], today: LocalDate, now: Date) -> [ItemID: ItemSummary] {
        var summaries: [ItemID: ItemSummary] = [:]
        for day in days {
            for dose in day.doses {
                let counted = isCounted(
                    hasEvent: !dose.record.events.isEmpty, date: day.date,
                    plannedAt: dose.occurrence.resolvedTime.earliestInstant, today: today, now: now
                )
                guard counted else { continue }
                var summary = summaries[dose.itemID] ?? ItemSummary(itemID: dose.itemID)
                switch dose.record.status {
                case .taken: summary.taken += 1
                case .skipped: summary.skipped += 1
                case .unrecorded: summary.noRecord += 1
                }
                summaries[dose.itemID] = summary
            }
            for dose in day.asNeeded where dose.record.status == .taken {
                var summary = summaries[dose.occurrence.itemID] ?? ItemSummary(itemID: dose.occurrence.itemID)
                summary.asNeededTaken += 1
                summaries[dose.occurrence.itemID] = summary
            }
        }
        return summaries
    }
}
