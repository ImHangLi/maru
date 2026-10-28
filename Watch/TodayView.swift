import MaruCore
import SwiftUI

/// The one screen of the Watch app: the doses of today by part of the day, like Today on the iPhone (D071).
struct TodayView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    /// The time of the last activation, or of the end of the list. A list of an earlier day does not show
    /// as today (spec 9).
    @State private var now = Date()
    private static let noticeID = "notice"

    var body: some View {
        // The Watch app is a Pro feature (D111). The last state that the iPhone sent decides, also for an old list.
        if let day = model.day, !day.isPro {
            LockedView(tint: day.tint.tint)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active { model.refresh() }
                }
        } else {
            list
        }
    }

    private var list: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if let notice = model.notice {
                        Label {
                            Text(notice.text)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .id(Self.noticeID)
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
                // The notice is at the top of the list. A request from a row lower down scrolls to it.
                .onChange(of: model.notice) { _, notice in
                    guard notice != nil else { return }
                    withAnimation { proxy.scrollTo(Self.noticeID, anchor: .top) }
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
            // watchOS draws only the symbol of a swipe action. The words are for VoiceOver. The symbols are those of the iPhone.
            if dose.status == .unrecorded {
                Button("Skip", systemImage: "minus.circle") { model.record(dose, as: .skipped) }
                    .tint(.gray)
            } else {
                Button("Undo", systemImage: "arrow.uturn.backward") { model.record(dose, as: .undo) }
                    .tint(.gray)
            }
        }
    }

    private var label: some View {
        HStack {
            CapsuleMark(status: dose.status, tint: tint, size: 28)
            VStack(alignment: .leading) {
                Text(verbatim: dose.name)
                Text(verbatim: detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The words of the row on the iPhone: "2 capsules, 8:00 AM", "2 capsules, Taken at 8:07 AM", or
    /// "2 capsules, Skipped". `time` is the intake time of a taken dose and the planned time of an open one.
    private var detail: String {
        let time = dose.time.formatted(.rowTime(in: .current))
        let state = switch dose.status {
        case .unrecorded: time
        case .taken: String(localized: "Taken at \(time)")
        case .skipped: String(localized: "Skipped")
        }
        return [dose.amount?.trimmingCharacters(in: .whitespacesAndNewlines), state].compactMap { $0 }.joined(separator: String(localized: ", "))
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
