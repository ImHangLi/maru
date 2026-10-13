import MaruCore
import SwiftUI

/// The one screen of the Watch app: the doses of today by part of the day, like Today on the iPhone (D065).
struct TodayView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The time of the last activation, or of the end of the list. A list of an earlier day does not show
    /// as today (spec 9).
    @State private var now = Date()

    var body: some View {
        NavigationStack {
            List {
                if let notice = model.notice {
                    Label {
                        Text(notice.text)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
                if let day = model.day, day.isCurrent(at: now) {
                    if day.slots.isEmpty {
                        Text("Nothing to Take Today")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(day.slots) { slot in
                        Section {
                            ForEach(slot.doses) { dose in
                                DoseRow(dose: dose, tint: day.tint.tint)
                            }
                        } header: {
                            Text(slot.part.title)
                        }
                    }
                    // The list can be old, so it shows its time (spec 10).
                    Text("Updated \(day.sentAt.formatted(.rowTime(in: .current)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    Text("Open Maru on your iPhone to update.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Today")
        }
        // Only after the iPhone confirmed the commit (spec 7.2).
        .sensoryFeedback(.success, trigger: model.confirmedCount)
        .sensoryFeedback(trigger: model.notice) { _, notice in notice == nil ? nil : .error }
        // The screen can stay in front over midnight, also with no iPhone in reach. The rows leave at the end of the list.
        .task(id: model.day?.expiresAt) {
            guard let expiresAt = model.day?.expiresAt else { return }
            try? await Task.sleep(for: .seconds(max(expiresAt.timeIntervalSinceNow, 0) + 1))
            guard !Task.isCancelled else { return }
            now = Date()
            model.refresh()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            now = Date()
            model.refresh()
        }
    }
}

/// One dose: the capsule of the widgets, the name, and a second line with the amount and the time.
/// A tap on an open dose records it as taken. A swipe gives "Skip", or "Undo" for a recorded dose,
/// with the words of the iPhone (D058).
private struct DoseRow: View {
    @Environment(WatchModel.self) private var model
    let dose: WatchDay.Dose
    let tint: Color

    var body: some View {
        Group {
            if dose.status == .unrecorded {
                Button { model.record(dose, as: .taken) } label: { label }
            } else {
                label
            }
        }
        // The request runs. The capsule fills only when the iPhone confirms.
        .opacity(model.inFlight.contains(dose.id) ? 0.5 : 1)
        .swipeActions(edge: .trailing) {
            if dose.status == .unrecorded {
                Button("Skip") { model.record(dose, as: .skipped) }
            } else {
                Button("Undo") { model.record(dose, as: .undo) }
            }
        }
    }

    private var label: some View {
        HStack {
            CapsuleMark(isTaken: dose.status == .taken, tint: tint, size: 28)
            VStack(alignment: .leading) {
                Text(verbatim: dose.name)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// For example "2 capsules, 8:00 AM" or "2 capsules, Skipped". A taken dose shows its intake time.
    private var detail: String {
        let state = dose.status == .skipped
            ? String(localized: "Skipped")
            : dose.time.formatted(.rowTime(in: .current))
        return [dose.amount, state].compactMap { $0 }.joined(separator: String(localized: ", "))
    }
}

private extension WatchModel.Notice {
    var text: LocalizedStringResource {
        switch self {
        case .notReachable: "Your iPhone is not reachable. Nothing was recorded."
        case .notConfirmed: "Your iPhone did not confirm. Check Maru on your iPhone."
        case .changed: "This dose changed on your iPhone. Nothing was recorded."
        case .notRecorded: "Not recorded. Open Maru on your iPhone."
        case .locked: "Not recorded. Unlock your iPhone and try again."
        }
    }
}
