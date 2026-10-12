import MaruCore
import SwiftUI

/// The confirmation of a tapped reminder that is not certain (spec 8.3, T15, T24).
///
/// It lists the candidate dates and parts of the day. A candidate of today opens its card on Today,
/// where the user records with the circle. A candidate of another day asks for the time it was taken.
/// A candidate with an event that the store did not confirm offers only a retry of that event (D014).
/// Nothing is recorded until the user saves.
struct ReminderChoiceSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let choice: ReminderChoice
    @State private var editing: ReminderChoice.Candidate?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(choice.candidates) { candidate in
                        row(candidate)
                    }
                } footer: {
                    message
                }
            }
            .listStyle(.insetGrouped)
            #if DEBUG
            .modifier(DebugDataBanner())
            #endif
            .navigationTitle("Which Reminder?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Open Today") { dismiss() }
                }
            }
        }
        .smallSheet()
        .sheet(item: $editing) { candidate in
            ChangeTimeSheet(
                name: candidate.name,
                time: candidate.takenAt ?? min(candidate.plannedInstant, .now),
                earliest: candidate.plannedInstant.addingTimeInterval(-24 * 60 * 60)
            ) { model.recordTaken(candidate, at: $0) }
        }
    }

    private func row(_ candidate: ReminderChoice.Candidate) -> some View {
        let isToday = candidate.isToday
        let isPending = model.pendingEvent(of: candidate) != nil
        // A date that no generation run reached has nothing to record here. Its row is no button, and it says
        // so with a symbol and the text color, not with gray (design principle 6).
        let isAvailable = isToday || candidate.occurrence != nil
        let content = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: candidate.name)
                    .foregroundStyle(.primary)
                Text(detail(candidate, isPending: isPending))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if isAvailable {
                Text(action(candidate, isPending: isPending))
                    .foregroundStyle(.tint)
            } else {
                Label("Not Available", systemImage: "nosign")
                    .foregroundStyle(.primary)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        return Group {
            if isAvailable {
                Button {
                    if isToday {
                        model.show(candidate)
                    } else if isPending {
                        model.retry(candidate)
                    } else {
                        editing = candidate
                    }
                } label: {
                    content
                }
                .buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    /// For example "Morning, Yesterday, Taken at 8:02".
    private func detail(_ candidate: ReminderChoice.Candidate, isPending: Bool) -> String {
        var parts = [String(localized: DayPart(candidate.plannedTime).title), day(candidate)]
        if let amount = candidate.amount { parts.insert(amount, at: 0) }
        // The stored record can show the event, but the store did not confirm it (D014, T19).
        if isPending {
            parts.append(String(localized: "Not saved"))
        } else if let takenAt = candidate.takenAt {
            parts.append(String(localized: "Taken at \(takenAt.formatted(timeFormat(candidate)))"))
        } else if candidate.record?.status == .skipped {
            parts.append(String(localized: "Skipped"))
        }
        return parts.formatted(.list(type: .and, width: .narrow))
    }

    private func action(_ candidate: ReminderChoice.Candidate, isPending: Bool) -> LocalizedStringKey {
        if candidate.isToday { return "Show" }
        if isPending { return "Try Again" }
        return candidate.takenAt == nil ? "Record…" : "Change Time…"
    }

    private func day(_ candidate: ReminderChoice.Candidate) -> String {
        if candidate.isToday { return String(localized: "Today") }
        if candidate.isYesterday { return String(localized: "Yesterday") }
        var format = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.abbreviated).day()
        format.timeZone = timeZone(candidate)
        return candidate.plannedInstant.formatted(format)
    }

    private func timeFormat(_ candidate: ReminderChoice.Candidate) -> Date.FormatStyle {
        .rowTime(in: timeZone(candidate))
    }

    private func timeZone(_ candidate: ReminderChoice.Candidate) -> TimeZone {
        TimeZone(identifier: candidate.timeZone.identifier) ?? .current
    }

    /// Why the app asks. The delay of a reminder says nothing about when the dose was taken (T24).
    private var message: Text {
        if !choice.doubts.isDisjoint(with: [.delayed, .zoneChange]) {
            Text("This reminder came late, or your time zone changed.")
        } else if !choice.doubts.isDisjoint(with: [.olderPlan, .noMatch, .clockChange]) {
            Text("Your plan or the clock changed after this reminder was set.")
        } else {
            Text("This reminder is for another day.")
        }
    }
}
