import Foundation

/// A value that a group of items share, or not (D085).
public enum SharedValue<Value: Hashable & Sendable>: Hashable, Sendable {
    /// The group has no value to share, for example no item.
    case empty
    case same(Value)
    case varies

    public init(_ values: some Sequence<Value>) {
        let distinct = Set(values)
        switch distinct.count {
        case 0: self = .empty
        case 1: self = .same(distinct.first!)
        default: self = .varies
        }
    }
}

/// What the reminder options of the items that have a time have in common. Settings shows it (D085).
public struct ReminderOptionsSummary: Hashable, Sendable {
    /// `nil` inside `.same` means that every item has "Remind Again" off.
    public let followUpCount: SharedValue<FollowUpCount?>
    /// The interval of the items that have "Remind Again" on. `.empty` when no item has it on.
    public let followUpInterval: SharedValue<FollowUpInterval>
    public let alarm: SharedValue<Bool>

    public init(items: [Item]) {
        followUpCount = SharedValue(items.map { $0.followUp?.count })
        followUpInterval = SharedValue(items.compactMap { $0.followUp?.interval })
        alarm = SharedValue(items.map(\.alarm))
    }
}
