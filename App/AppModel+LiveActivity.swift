import ActivityKit
import Foundation
import MaruCore
import MaruDatabase
import os
import UIKit

/// The switch "Next Dose on Lock Screen" and the updates of its Live Activity (D110).
struct LiveActivityState {
    /// The switch, in `UserDefaults.standard` beside the display settings. It holds no item data.
    static let isOnKey = "liveActivity.nextDose"

    /// Only a Pro user turns it on. A loss of Pro turns it off.
    var isOn = UserDefaults.standard.bool(forKey: isOnKey)
    /// Live Activities are on for Maru in the Settings app. Settings shows a footer when they are off. The launch does
    /// not ask the system (spec 9). Settings, each return to the front, and each update read it.
    var systemAllows = true
    /// The updates run one after the other, so an older one never comes after a newer one.
    var update: Task<Void, Never>?
    var isUpdateQueued = false
}

/// What the app asks of the Live Activity.
enum NextDoseChange: Sendable {
    case end
    /// Shows the next dose. Only an app in front can start an activity, so `canStart` is false in the background.
    case show(NextDoseAttributes.ContentState, staleDate: Date, canStart: Bool)
    /// "Taken" did not get a confirmed commit.
    case notConfirmed
    /// "Taken" had an unknown or older token. The activity asks to open Maru.
    case expire
}

/// The doses of the activity, on the device (D110). The content of the activity holds only the token, because
/// ActivityKit limits it to 4 KB. A new set of doses, schedule versions, or restore epoch gets a new token, so an older
/// "Taken" records nothing. It holds no name and no amount.
struct NextDoseSlot: Codable, Equatable {
    static let key = "liveActivity.nextDose.slot"

    var token: String
    var occurrenceIDs: [UUID]
    var scheduleVersionIDs: [UUID]
    var epoch: Int
    /// The members of the doses, in the order of the doses. A new owner gives a new token (D123).
    var personIDs: [UUID] = []
    /// The instant at which the app made these doses. "Taken" records nothing for an item whose owner changed after it (D123).
    var listedAt = Date.distantPast

    static var stored: NextDoseSlot? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(NextDoseSlot.self, from: $0) }
    }

    /// Keeps the doses, and returns their token. The same doses keep their token, so the content does not change.
    static func store(occurrenceIDs: [UUID], scheduleVersionIDs: [UUID], personIDs: [UUID], epoch: Int, at now: Date) -> String {
        if var slot = stored, slot.occurrenceIDs == occurrenceIDs, slot.scheduleVersionIDs == scheduleVersionIDs,
           slot.personIDs == personIDs, slot.epoch == epoch {
            // The same doses with the same owners: the new read is the list now. An owner change away and back must not keep
            // an instant from before it, or "Taken" never records again (D123).
            if now > slot.listedAt {
                slot.listedAt = now
                UserDefaults.standard.set(try? JSONEncoder().encode(slot), forKey: key)
            }
            return slot.token
        }
        let slot = NextDoseSlot(
            token: String(UUID().uuidString.prefix(8)),
            occurrenceIDs: occurrenceIDs,
            scheduleVersionIDs: scheduleVersionIDs,
            epoch: epoch,
            personIDs: personIDs,
            listedAt: now
        )
        UserDefaults.standard.set(try? JSONEncoder().encode(slot), forKey: key)
        return slot.token
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

extension AppModel {
    /// The switch in Settings. A free user gets the paywall, and the switch stays off (D107).
    func setNextDoseOnLockScreen(_ isOn: Bool) {
        guard isOn else { return turnOffNextDose() }
        guard pro.isPro else { return presentPaywall(reason: .liveActivity) }
        liveActivity.isOn = true
        UserDefaults.standard.set(true, forKey: LiveActivityState.isOnKey)
        noteProUse()
        updateNextDose()
    }

    private func turnOffNextDose() {
        liveActivity.isOn = false
        UserDefaults.standard.set(false, forKey: LiveActivityState.isOnKey)
        noteProUse()
        enqueueNextDose { .end }
    }

    /// StoreKit read the entitlement (D107). A loss of Pro, for example after an expiry or a refund, ends the activity
    /// and turns the switch off. The cached plan at launch does not turn it off, because a renewal can come after the
    /// cached end of access.
    func proEntitlementDidLoad() {
        noteProUse()
        if pro.isPro {
            updateNextDose()
        } else if liveActivity.isOn {
            turnOffNextDose()
        }
    }

    /// The user can change the system switch in the Settings app while Maru is away.
    func readLiveActivityPermission() {
        liveActivity.systemAllows = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Updates the activity from the Today that the model shows: after each read that shows, and after each commit.
    func updateNextDose() {
        guard liveActivity.isOn, !liveActivity.isUpdateQueued else { return }
        liveActivity.isUpdateQueued = true
        enqueueNextDose {
            self.liveActivity.isUpdateQueued = false
            guard case let .loaded(snapshot) = self.content, let day = snapshot.today else { return nil }
            return await self.nextDoseChange(for: day)
        }
    }

    /// Updates the activity from a new read, and returns when the update ends. A record or a reminder run in the
    /// background calls it, because the system can suspend the process when the call returns.
    func updateNextDoseNow() async {
        guard liveActivity.isOn else { return }
        await enqueueNextDose {
            guard let today = try? await self.freshToday() else { return nil }
            return await self.nextDoseChange(for: today.day)
        }.value
    }

    @discardableResult
    private func enqueueNextDose(_ change: @escaping @MainActor () async -> NextDoseChange?) -> Task<Void, Never> {
        let previous = liveActivity.update
        let task = Task {
            await previous?.value
            if let change = await change() { await NextDoseActivity.apply(change) }
        }
        liveActivity.update = task
        return task
    }

    /// The earliest open planned time of today, with every open dose of that time. A dose with an event that the store
    /// did not confirm is left out: it goes again only from Today (D014). `nil` changes nothing.
    private func nextDoseChange(for day: TodaySnapshot) async -> NextDoseChange? {
        let now = Date()
        let generation = dataGeneration
        guard liveActivity.isOn, pro.isPro else { return nil }
        readLiveActivityPermission()
        // The system ends every activity when the user turns Live Activities off.
        guard liveActivity.systemAllows else { return .end }
        // Another day or another time zone. The next read updates the activity.
        guard day.isCurrent(at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now)),
              let timeZone = TimeZone(identifier: day.timeZone.identifier) else { return nil }
        let open = day.groups.flatMap { group in
            group.entries.filter { $0.isOpen && today.pending[$0.id] == nil }.map { (part: group.part, entry: $0) }
        }
        guard let plannedAt = open.map({ Self.plannedInstant($0.entry) }).min() else { return .end }
        let doses = open.filter { Self.plannedInstant($0.entry) == plannedAt }
        // A restore that runs, or that ended during the read, gives the next read.
        guard let epoch = await store.restoreEpoch(), epoch % 2 == 0, generation == dataGeneration else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let token = NextDoseSlot.store(
            occurrenceIDs: doses.map(\.entry.id.rawValue),
            scheduleVersionIDs: doses.map(\.entry.occurrence.scheduleVersionID.rawValue),
            personIDs: doses.map(\.entry.look.personID.rawValue),
            epoch: epoch,
            // The read of the doses, not the clock now: an owner change after the read refuses the record (D123).
            at: day.generatedAt
        )
        let state = NextDoseAttributes.ContentState(
            part: doses[0].part.linkName,
            plannedAt: plannedAt,
            timeZone: timeZone.identifier,
            names: showsNamesInReminders ? Self.shownNames(doses.map(\.entry.look.labelledName)) : [],
            count: doses.count,
            token: token,
            expiresAt: endOfDay,
            // The button records for one member only (D123).
            canRecord: Set(doses.map(\.entry.look.personID)).count == 1
        )
        // Never during the onboarding (D103). An app in the background can only update or end an activity.
        let canStart = onboarding == .hidden && UIApplication.shared.applicationState == .active
        return .show(state, staleDate: endOfDay, canStart: canStart)
    }

    /// The names that the activity shows: at most three, in a limit of bytes, so the content stays far below the
    /// 4 KB of ActivityKit. A long name ends with "…". The activity shows the number of the other doses.
    private static func shownNames(_ names: [String]) -> [String] {
        var shown: [String] = []
        var bytesLeft = 600
        for name in names.prefix(3) {
            var fitted = ""
            for character in name {
                // Three bytes stay free for the "…".
                guard character.utf8.count + 3 <= bytesLeft else { break }
                fitted.append(character)
                bytesLeft -= character.utf8.count
            }
            guard !fitted.isEmpty else { break }
            guard fitted.count == name.count else {
                shown.append(fitted + "…")
                break
            }
            shown.append(fitted)
        }
        return shown
    }

    /// The "Taken" button of the Live Activity (D110). The system runs it in this process, also in the background.
    ///
    /// It records the doses of the token that the activity shows. An unknown or older token records nothing, and
    /// the activity asks to open Maru. Then the checks of the "Record Dose" widget apply (D048): the restore epoch must
    /// be the one of the token, and each dose must still be the same occurrence and schedule version, today, and open.
    /// The record transaction checks the active item and the plan of now (`requiresCurrentPlan`). Each event revises the
    /// record that this call read, so a second tap writes nothing (T18). A dose with a record already needs no event.
    ///
    /// The activity changes only after the commit and the reminder run (spec 7.2, D047): it shows the next dose, or it ends.
    /// When a check fails, it records nothing and shows the doses of now. When the commit does not confirm, the activity
    /// says so, and Today keeps the events for a retry (D014).
    func takeNextDose(_ intent: TakeNextDoseIntent) async {
        analytics.markUsed(.liveActivity)
        // The generation comes before the first await, so a restore after this line refuses the record (D040).
        let generation = dataGeneration
        let now = Date()
        guard let slot = NextDoseSlot.stored, slot.token == intent.token else {
            return await enqueueNextDose { .expire }.value
        }
        let epoch = await store.restoreEpoch()
        var events: [PendingEvent] = []
        var confirmed: [OccurrenceID: OccurrenceRecord] = [:]
        var isCurrent = epoch == slot.epoch && slot.epoch % 2 == 0 && !slot.occurrenceIDs.isEmpty
            && slot.occurrenceIDs.count == slot.scheduleVersionIDs.count && Set(slot.personIDs).count == 1
        for (occurrenceID, versionID) in zip(slot.occurrenceIDs, slot.scheduleVersionIDs) where isCurrent {
            guard let target = try? await store.widgetTarget(
                of: OccurrenceID(occurrenceID), scheduleVersionID: ScheduleVersionID(versionID), at: now
            ) else {
                isCurrent = false
                continue
            }
            switch target {
            case let .open(occurrence, record):
                var event = PendingEvent(
                    event: record.nextEvent(.taken, at: now, source: .app),
                    scheduleVersionID: occurrence.scheduleVersionID
                )
                event.requiresCurrentPlan = true
                event.restoreEpoch = slot.epoch
                event.listedAt = slot.listedAt
                events.append(event)
                confirmed[occurrence.id] = record
            case .alreadyTaken:
                continue
            case .none:
                isCurrent = false
            }
        }
        // The activity showed an older state. Nothing was written.
        guard isCurrent else { return await updateNextDoseNow() }
        let isRecorded: Bool
        if events.isEmpty {
            // Every dose has its record. A first tap can have committed and failed to flush, so flush again.
            let isFlushed = await store.flushCommits()
            isRecorded = isFlushed && generation == dataGeneration
        } else {
            isRecorded = await commitAndWait(events, generation: generation, confirmed: confirmed)
        }
        guard isRecorded else {
            return await enqueueNextDose { .notConfirmed }.value
        }
        // The run of the reminders also updates the activity.
        if let deviceTimeZone = NamedTimeZone(device: .current, at: Date()) {
            await waitForReminders(deviceTimeZone: deviceTimeZone)
        } else {
            await updateNextDoseNow()
        }
    }
}

/// The calls to ActivityKit (D110). They run off the main actor, because an `Activity` is not `Sendable`.
enum NextDoseActivity {
    /// An activity older than this starts again when Maru is in front. The system ends an activity 8 hours after its
    /// start, so the activity lasts until 8 hours after the last open of Maru.
    static let renewAge: TimeInterval = 60 * 60

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Maru", category: "liveActivity")

    static func apply(_ change: NextDoseChange) async {
        let all = Activity<NextDoseAttributes>.activities
        let live = all.filter { $0.activityState == .active || $0.activityState == .stale }
        switch change {
        case .end:
            NextDoseSlot.clear()
            for activity in all {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        case .notConfirmed:
            for activity in live {
                var state = activity.content.state
                state.isNotConfirmed = true
                await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
            }
        case .expire:
            let now = Date()
            for activity in live {
                var state = activity.content.state
                state.expiresAt = now
                await activity.update(ActivityContent(state: state, staleDate: now))
            }
        case let .show(state, staleDate, canStart):
            let now = Date()
            let content = ActivityContent(state: state, staleDate: staleDate)
            if let current = live.first, !(canStart && now.timeIntervalSince(current.attributes.startedAt) > renewAge) {
                for extra in live.dropFirst() {
                    await extra.end(nil, dismissalPolicy: .immediate)
                }
                if current.content.state != state || current.content.staleDate != staleDate {
                    await current.update(content)
                }
                return
            }
            guard canStart else { return }
            do {
                _ = try Activity<NextDoseAttributes>.request(
                    attributes: NextDoseAttributes(startedAt: now), content: content, pushType: nil
                )
            } catch {
                // The error has no item data.
                log.error("The Live Activity did not start: \(String(describing: error), privacy: .public)")
                return
            }
            // The new activity is up, so the old ones end. An activity that the system ended leaves the Lock Screen too.
            for old in all {
                await old.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
