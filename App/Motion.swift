import SwiftUI
import UIKit

/// The one motion language of the app (D030, docs/design.md "Motion").
///
/// The same kind of change uses the same case on every page. A change with no case here shows at once.
/// System sheets, pushes, menus, alerts, and swipe actions keep the motion of the system.
enum Motion {
    /// A change that moves the layout: a section that folds or opens, a row or a section that comes or goes,
    /// a line that comes or goes in a row, and the change between an empty page and a list.
    case layout
    /// A change in place, with no move: the record symbol and a mark in a header.
    case state
    /// The slow fade of the opening highlight on the current part of the day (D020).
    case attention

    /// With Reduce Motion nothing moves, so a layout change shows at once (spec 5.3). The other two cases
    /// are fades with no move, and they stay.
    func animation(reduceMotion: Bool) -> Animation? {
        switch self {
        case .layout: reduceMotion ? nil : .snappy
        case .state: .easeInOut(duration: 0.2)
        case .attention: .easeOut(duration: 1.2)
        }
    }
}

/// Runs a change of the model or of a view state with a motion case. `nil` shows the change at once.
@MainActor
func withMotion<Result>(_ motion: Motion?, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(motion?.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled), body)
}

extension View {
    /// Gives a motion case to each change of this view that comes with a new `value`.
    func motion(_ motion: Motion, value: some Equatable) -> some View {
        modifier(MotionModifier(motion: motion, value: value))
    }

    /// An SF Symbol that changes in place: the system replace effect with the state motion.
    /// With Reduce Motion the symbols cross-fade, with no scale.
    func symbolMotion(value: some Equatable) -> some View {
        modifier(SymbolMotionModifier(value: value))
    }
}

private struct MotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let motion: Motion
    let value: Value

    func body(content: Content) -> some View {
        content.animation(motion.animation(reduceMotion: reduceMotion), value: value)
    }
}

private struct SymbolMotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content
            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            .animation(Motion.state.animation(reduceMotion: reduceMotion), value: value)
    }
}
