import Foundation
import MaruCore

extension AppModel {
    /// Sends the list of today to the Watch app, after each read and each commit (D065).
    ///
    /// The list goes only to a paired Watch that has the Watch app. WatchConnectivity sends it between the two
    /// devices with the encryption of the system, and through no server of Maru.
    func sendWatchDay() {
        let now = Date()
        guard WatchLink.shared.hasWatchApp, case let .loaded(snapshot) = content, let day = snapshot.today,
              day.isCurrent(at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now))
        else { return }
        WatchLink.shared.send(WatchDay(day, unsaved: Set(today.pending.keys), at: now))
    }

    /// Answers a request of the Watch app (D065). The system can start Maru in the background for it.
    ///
    /// The reply says "recorded" only after the record transaction committed (spec 7.2). In every other case
    /// it says "not recorded": a locked iPhone, a dose that is not in the list of today any more, another plan,
    /// an event that is not confirmed, a restore, or a failed commit. The reply also has the list after the request.
    func answerWatch(_ message: Data) async -> Data {
        var recorded = false
        if case let .record(id, scheduleVersionID, action) = WatchRequest(message: message) {
            recorded = await recordFromWatch(id, scheduleVersionID: scheduleVersionID, action)
        }
        let day = await readToday(generation: dataGeneration).map {
            WatchDay($0, unsaved: Set(today.pending.keys), at: Date())
        }
        return WatchReply(recorded: recorded, day: day).message ?? Data()
    }

    /// Records one dose with the transaction of the record circle. The source of the event is `app`.
    ///
    /// The Watch can show an old list, so the dose comes from a new read: the same occurrence and schedule
    /// version, in the list of today. A dose that has the asked state already needs no new event, for example
    /// when the first reply did not reach the Watch. A success then needs a flush, as for the widget (D048).
    /// After the commit it waits for the reminder run (D047), because the system can suspend the process
    /// after the reply.
    private func recordFromWatch(
        _ id: OccurrenceID, scheduleVersionID: ScheduleVersionID, _ action: IntakeAction
    ) async -> Bool {
        // The generation comes before the read, so a restore after this line refuses the record (D040).
        let generation = dataGeneration
        guard let day = await readToday(generation: generation),
              let entry = day.entries.first(where: { $0.id == id }),
              entry.occurrence.scheduleVersionID == scheduleVersionID,
              // An event that the store did not confirm goes again only from the iPhone (D014).
              today.pending[id] == nil
        else { return false }
        let asked: OccurrenceStatus = switch action {
        case .taken: .taken
        case .skipped: .skipped
        case .undo: .unrecorded
        }
        let committed: Bool
        if entry.record.status == asked {
            let flushed = await store.flushCommits()
            committed = flushed && generation == dataGeneration
        } else {
            committed = await commitAndWait([event(for: entry, action)], generation: generation)
        }
        if committed, let deviceTimeZone = NamedTimeZone(device: .current, at: Date()) {
            await waitForReminders(deviceTimeZone: deviceTimeZone)
        }
        return committed
    }

    /// The rows of today from a new read of the store, with the confirmed record of each running transaction.
    /// `nil` when the store gives none, for example on a locked iPhone.
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
    init(_ today: TodaySnapshot, unsaved: Set<OccurrenceID>, at now: Date) {
        self.init(
            sentAt: now,
            expiresAt: today.expiresAt,
            tint: AppGroup.appColor,
            slots: today.groups.map { group in
                Slot(part: group.part, doses: group.entries.map { entry in
                    let occurrence = entry.occurrence
                    let event = unsaved.contains(entry.id) ? nil : entry.record.currentEvent
                    return Dose(
                        id: entry.id,
                        scheduleVersionID: occurrence.scheduleVersionID,
                        name: entry.look.name,
                        amount: entry.amount,
                        status: unsaved.contains(entry.id) ? .unrecorded : entry.record.status,
                        time: event.flatMap { $0.action == .taken ? $0.occurredAt : nil }
                            ?? occurrence.timeZone.resolve(occurrence.plannedTime, on: occurrence.plannedDate).earliestInstant
                    )
                })
            }
        )
    }
}
