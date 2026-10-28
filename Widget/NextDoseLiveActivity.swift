import ActivityKit
import MaruCore
import SwiftUI
import WidgetKit

/// "Next Dose on Lock Screen", the Live Activity of Maru Pro (D110): the part of the day, the planned time and a relative
/// time, the item names or the number of doses, and "Taken". The app sets the content. This view only draws it.
///
/// The relative time moves on the screen with no update: "in 12 minutes" before the planned time, "12 minutes ago"
/// after it. The stale date is the end of the day of the dose. After it, the activity asks to open Maru and shows no
/// name and no button, so no button records a dose of another day.
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
                // The planned time, because a relative time does not fit in all languages. It needs no update.
                if shown.phase != .expired {
                    Text(shown.time).foregroundStyle(shown.tint)
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
        /// The day of the dose: the relative time, the doses, and "Taken".
        case open
        /// The day of the dose ended, or "Taken" had an older token. The activity asks to open Maru.
        case expired
        /// "Taken" did not get a confirmed commit.
        case notConfirmed
    }

    let state: NextDoseAttributes.ContentState
    let part: DayPart?
    let phase: Phase
    let tint: Color
    let time: String

    init(_ context: ActivityViewContext<NextDoseAttributes>) {
        state = context.state
        part = DayPart(linkName: state.part)
        // The system draws the activity again at each update and at the stale date.
        if context.isStale || state.expiresAt <= Date() {
            phase = .expired
        } else if state.isNotConfirmed {
            phase = .notConfirmed
        } else {
            phase = .open
        }
        tint = AppGroup.appColor.tint
        time = state.plannedAt.formatted(.rowTime(in: TimeZone(identifier: state.timeZone) ?? .current))
    }

    /// The names, or the number of doses when "Show Names in Reminders" is off (D029). The state has at most three
    /// names, so the list ends with the number of the other doses.
    var doses: Text {
        guard !state.names.isEmpty else { return Text("\(state.count) doses") }
        let more = state.count - state.names.count
        let names = more > 0 ? state.names + [String(localized: "\(more) more")] : state.names
        return Text(verbatim: names.formatted(.list(type: .and)))
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

/// The planned time relative to now. The system moves it on the screen, also across the planned time, so the activity
/// needs no update at the planned time. It never says "late" or "missed" (D101).
private struct NextDoseStatus: View {
    let shown: NextDoseShown

    var body: some View {
        if shown.phase == .open {
            relative
                .multilineTextAlignment(.trailing)
                .fixedSize()
        }
    }

    @ViewBuilder private var relative: some View {
        if #available(iOS 18, *) {
            // "in 12 minutes" before the planned time, "12 minutes ago" after it, in the language of the system.
            Text(.currentDate, format: .reference(to: shown.state.plannedAt, allowedFields: [.hour, .minute]))
        } else {
            // iOS 17 has no relative text with a direction. It shows the distance, "12 min", and the planned time
            // beside it tells before from after.
            Text(shown.state.plannedAt, style: .relative)
        }
    }
}

/// The doses and "Taken", or the text that asks to open Maru.
private struct NextDoseBody: View {
    let shown: NextDoseShown

    var body: some View {
        switch shown.phase {
        case .expired:
            Text("Open Maru to update.")
                .font(.headline)
        case .notConfirmed:
            VStack(alignment: .leading, spacing: 4) {
                shown.doses.font(.headline).lineLimit(2)
                // The dose can be stored, so the text does not say that nothing was recorded (spec 7.2, D014).
                Label("Couldn’t confirm the save. Open Maru to check.", systemImage: "exclamationmark.triangle")
                    .font(.footnote)
            }
        case .open:
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
