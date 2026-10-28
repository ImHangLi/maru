import ActivityKit
import MaruCore
import SwiftUI
import WidgetKit

/// "Next Dose on Lock Screen", the Live Activity of Maru Pro (D110): the part of the day, the planned time with the time
/// left, the item names or the number of doses, and "Taken". The app sets the content. This view only draws it.
///
/// After the planned time, the stale date makes the system draw it again, and it says "Not recorded yet". A dose that was
/// already past at the update gets the end of the day as its stale date. After it, the activity asks to open Maru, so no
/// button records a dose of another day.
struct NextDoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NextDoseAttributes.self) { context in
            NextDoseLockScreen(shown: NextDoseShown(context))
        } dynamicIsland: { context in
            let shown = NextDoseShown(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let part = shown.part { Text(part.title).foregroundStyle(shown.tint) }
                        Text(shown.time).foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    NextDoseStatus(shown: shown)
                        .font(.subheadline.weight(.semibold))
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    NextDoseBody(shown: shown)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "pills.fill").foregroundStyle(shown.tint)
            } compactTrailing: {
                switch shown.phase {
                case .upcoming:
                    Text(timerInterval: shown.countdown, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 56)
                case .overdue, .notConfirmed:
                    Text(shown.time).foregroundStyle(shown.tint)
                case .dayPassed:
                    EmptyView()
                }
            } minimal: {
                Image(systemName: "pills.fill").foregroundStyle(shown.tint)
            }
            .widgetURL(AppGroup.todayURL(shown.part))
            .keylineTint(shown.tint)
        }
    }
}

/// What the activity shows now, from its content and its stale state.
private struct NextDoseShown {
    enum Phase {
        /// Before the planned time: the time left.
        case upcoming
        /// After the planned time, on the same day.
        case overdue
        /// The dose was past at the update, and the day ended. The activity asks to open Maru.
        case dayPassed
        /// "Taken" did not get a confirmed commit.
        case notConfirmed
    }

    let state: NextDoseAttributes.ContentState
    let part: DayPart?
    let phase: Phase
    let tint: Color
    let countdown: ClosedRange<Date>
    let time: String

    init(_ context: ActivityViewContext<NextDoseAttributes>) {
        state = context.state
        part = DayPart(linkName: state.part)
        if state.isNotConfirmed {
            phase = .notConfirmed
        } else if state.isOverdue {
            phase = context.isStale ? .dayPassed : .overdue
        } else {
            phase = context.isStale ? .overdue : .upcoming
        }
        tint = AppGroup.appColor.tint
        countdown = min(context.attributes.startedAt, state.plannedAt)...state.plannedAt
        time = state.plannedAt.formatted(.rowTime(in: TimeZone(identifier: state.timeZone) ?? .current))
    }

    /// The names, or the number of doses when "Show Names in Reminders" is off (D029).
    var doses: Text {
        state.names.isEmpty ? Text("\(state.count) doses") : Text(verbatim: state.names.formatted(.list(type: .and)))
    }
}

private struct NextDoseLockScreen: View {
    let shown: NextDoseShown

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "pills.fill").foregroundStyle(shown.tint)
                if let part = shown.part { Text(part.title).foregroundStyle(shown.tint) }
                Text(shown.time).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                NextDoseStatus(shown: shown)
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            NextDoseBody(shown: shown)
        }
        .padding(16)
        .widgetURL(AppGroup.todayURL(shown.part))
    }
}

/// The time left, or the state after the planned time. States use the text color and a symbol (D058).
private struct NextDoseStatus: View {
    let shown: NextDoseShown

    var body: some View {
        switch shown.phase {
        case .upcoming:
            Text(timerInterval: shown.countdown, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .fixedSize()
        case .overdue:
            Label("Not recorded yet", systemImage: "clock")
        case .dayPassed, .notConfirmed:
            EmptyView()
        }
    }
}

/// The doses and "Taken", or the text that asks to open Maru.
private struct NextDoseBody: View {
    let shown: NextDoseShown

    var body: some View {
        switch shown.phase {
        case .dayPassed:
            Text("Open Maru to update.")
                .font(.headline)
        case .notConfirmed:
            VStack(alignment: .leading, spacing: 4) {
                shown.doses.font(.headline).lineLimit(2)
                // The dose can be stored, so the text does not say that nothing was recorded (spec 7.2, D014).
                Label("Couldn’t confirm the save. Open Maru to check.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
            }
        case .upcoming, .overdue:
            HStack(alignment: .center, spacing: 12) {
                shown.doses
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                // The app records only after the unlock and the checks of the record. The activity changes after the commit.
                Button(intent: TakeNextDoseIntent(shown.state)) {
                    Text("Taken")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(shown.tint)
                .accessibilityHint(
                    shown.state.count == 1 ? Text("Records this dose as taken") : Text("Records these doses as taken")
                )
            }
        }
    }
}
