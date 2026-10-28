import Foundation
import MaruCore

extension AppModel {
    /// Sends the list of today to the Watch app, after each read, each commit, and each change of Maru Pro (D071, D111).
    ///
    /// The list goes only to a paired Watch that has the Watch app. WatchConnectivity sends it between the two
    /// devices with the encryption of the system, and through no server of Maru. The Watch app is a Pro feature, so
    /// a free user's list has no dose.
    func sendWatchDay() {
        let now = Date()
        guard WatchLink.shared.hasWatchApp, case let .loaded(snapshot) = content, let day = snapshot.today,
              day.isCurrent(at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now))
        else { return }
        WatchLink.shared.send(WatchDay(day, unsaved: Set(today.pending.keys), isPro: pro.isPro, at: now))
    }

    /// Answers a request of the Watch app (D071). The system can start Maru in the background for it.
    ///
    /// The reply says "recorded" only after the record transaction committed (spec 7.2). It says "changed" when
    /// the dose is not the one that the Watch showed. In every other case it says "not recorded": a free user (D111), an
    /// iPhone that was not unlocked after a restart, an event that is not confirmed, a restore, or a failed commit. The
    /// reply also has the list after the request.
    func answerWatch(_ message: Data) async -> Data {
        var outcome = WatchReply.Outcome.notRecorded
        switch WatchRequest(message: message) {
        case let .record(id, scheduleVersionID, action, revision, intent):
            outcome = await recordFromWatch(
                id, scheduleVersionID: scheduleVersionID, action, revision: revision, intent: intent
            )
        case .showPro:
            watchAskedForPro()
        case .today, nil:
            break
        }
        let isPro = await confirmedPro()
        let day = await readToday(generation: dataGeneration).map {
            WatchDay($0, unsaved: Set(today.pending.keys), isPro: isPro, at: Date())
        }
        return WatchReply(outcome: outcome, day: day).message ?? Data()
    }

    /// Records one dose with the record transaction. The source of the event is `app`.
    ///
    /// The Watch app is a Pro feature (D111). A free user's request records nothing, also from a Watch that still shows
    /// an old Pro list.
    ///
    /// The Watch can show an old list, so the dose comes from a new read, and four checks come before the write:
    /// - The read is still of today when it ends. A request from before midnight records nothing after it.
    /// - The dose is in the list of today, with the schedule version that the Watch showed.
    /// - The record is the one that the Watch showed: its last event is `revision`. A change on the iPhone
    ///   in between, for example a new intake time, makes the row of the Watch old, and it records nothing.
    /// - The intent is new. `intent` is the ID of the event. When that event is the end of the record already,
    ///   for example because the first reply did not reach the Watch, nothing is written, and a success
    ///   needs a flush, as for the widget (D048). A later choice after that event stays.
    /// The transaction checks the same again: the event revises `revision` and has the ID `intent`, so the store
    /// rejects it on another record state and for a used ID (T18), and `requiresCurrentPlan` checks the day and
    /// the plan of now. After the commit the call waits for the reminder run (D047), because the system can
    /// suspend the process after the reply.
    private func recordFromWatch(
        _ id: OccurrenceID, scheduleVersionID: ScheduleVersionID, _ action: IntakeAction,
        revision: IntakeEventID?, intent: IntakeEventID
    ) async -> WatchReply.Outcome {
        guard await confirmedPro() else { return .notRecorded }
        // The generation comes before the read, so a restore after this line refuses the record (D040).
        let generation = dataGeneration
        guard let day = await readToday(generation: generation),
              // An event that the store did not confirm goes again only from the iPhone (D014).
              today.pending[id] == nil
        else { return .notRecorded }
        let now = Date()
        guard day.isCurrent(at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now)),
              let entry = day.entries.first(where: { $0.id == id }),
              entry.occurrence.scheduleVersionID == scheduleVersionID
        else { return .changed }
        let committed: Bool
        switch entry.record.watchStep(intent: intent, revision: revision) {
        case .changed:
            return .changed
        case .applied:
            let flushed = await store.flushCommits()
            committed = flushed && generation == dataGeneration
        case .write:
            var event = PendingEvent(
                event: IntakeEvent(
                    id: intent, occurrenceID: id, action: action, occurredAt: now, recordedAt: now,
                    source: .app, supersedes: revision
                ),
                scheduleVersionID: scheduleVersionID
            )
            event.requiresCurrentPlan = true
            // The read record stays on the Watch until the commit is flushed (spec 7.2).
            committed = await commitAndWait([event], generation: generation, confirmed: [id: entry.record])
        }
        guard committed else { return .notRecorded }
        if let deviceTimeZone = NamedTimeZone(device: .current, at: Date()) {
            await waitForReminders(deviceTimeZone: deviceTimeZone)
        }
        return .recorded
    }

    /// `true` for Maru Pro. A free answer reads StoreKit again before it counts, because the system can start Maru for a
    /// request of the Watch before the first read of StoreKit ends, for example after a renewal while Maru did not run.
    private func confirmedPro() async -> Bool {
        if pro.isPro { return true }
        await pro.refreshEntitlement()
        return pro.isPro
    }

    /// The rows of today from a new read of the store, with the confirmed record of each running transaction.
    /// `nil` when the store gives none, for example after a restart and before the first unlock.
    private func readToday(generation: Int) async -> TodaySnapshot? {
        let now = Date()
        guard let deviceTimeZone = NamedTimeZone(device: .current, at: now),
              var day = try? await store.snapshot(at: now, deviceTimeZone: deviceTimeZone, generation: generation).today,
              generation == dataGeneration
        else { return nil }
        day.apply(heldRecords)
        return day
    }
}

private extension WatchDay {
    /// - Parameter unsaved: The occurrences with an event that the store did not confirm. Such a dose is not
    ///   done, also when the read shows the stored event (D014), so the Watch gets it as open.
    init(_ today: TodaySnapshot, unsaved: Set<OccurrenceID>, isPro: Bool, at now: Date) {
        self.init(
            sentAt: now,
            expiresAt: today.expiresAt,
            tint: AppGroup.appColor,
            isPro: isPro,
            // A free user's list has no dose (D111).
            slots: !isPro ? [] : today.groups.map { group in
                Slot(part: group.part, doses: group.entries.map { entry in
                    let occurrence = entry.occurrence
                    let event = unsaved.contains(entry.id) ? nil : entry.record.currentEvent
                    return Dose(
                        id: entry.id,
                        scheduleVersionID: occurrence.scheduleVersionID,
                        name: entry.look.name,
                        amount: entry.amount,
                        status: unsaved.contains(entry.id) ? .unrecorded : entry.record.status,
                        revision: entry.record.events.last?.id,
                        time: event.flatMap { $0.action == .taken ? $0.occurredAt : nil }
                            ?? occurrence.timeZone.resolve(occurrence.plannedTime, on: occurrence.plannedDate).earliestInstant
                    )
                })
            }
        )
    }
}
