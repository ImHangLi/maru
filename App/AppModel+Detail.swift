import Foundation
import MaruCore
import MaruDatabase

/// What the system holds for one schedule after a run of the reminder engine (spec 8.1, T03).
///
/// Maru shows no message after a save or a change. The list and the detail show the result in place, as
/// in Apple Health. The item detail shows this state, and an alert comes only when a reminder failed (D028).
enum ReminderStatus: Equatable {
    case set
    /// The schedule asks for no reminder: the reminders are off, or the item is archived.
    case off
    /// Maru did not ask for the notification permission yet. A save with a time asks (spec 2.2).
    case notAsked
    case notificationsOff
    case tooMany
    /// The plan is saved, and the system does not hold its reminder.
    case notSet
    /// The system did not confirm a removal yet. The reminder is not confirmed.
    case notConfirmed

    init(_ state: ReminderState) {
        self = switch state {
        case .scheduled: .set
        case .off: .off
        case .notSet(.permissionNotAsked): .notAsked
        case .notSet(.permissionDenied): .notificationsOff
        case .notSet(.overLimit): .tooMany
        case .notSet: .notSet
        case .removalPending: .notConfirmed
        }
    }
}

/// A reminder problem right after a save or a change. The plan is saved, so the alert says only what failed.
struct ReminderAlert: Identifiable, Equatable {
    enum Kind: Equatable {
        case tooMany, notSet, notConfirmed
        /// A removal that the system did not confirm, after off, archive, or a replacement with no time.
        case mayStillRemind
    }

    let id = UUID()
    let kind: Kind
}

/// An archive or a delete of an item that waits for its one confirmation (D033).
struct ItemEndRequest: Equatable {
    enum Kind: Equatable {
        case archive, delete
    }

    let kind: Kind
    let itemID: ItemID
    /// The confirmation names the item.
    let name: String
}

extension AppModel {
    /// The detail of one item. `nil` when the store has no such item.
    func detail(of itemID: ItemID) async throws -> ItemDetail? {
        noteUse(.itemDetail)
        let now = Date()
        return try await store.detail(of: itemID, at: now, deviceTimeZone: NamedTimeZone(device: .current, at: now))
    }

    /// "Replace with a new product": the edit screen of a new item that starts with the type, form, color, plan,
    /// and note of the old item, and no amount. The app converts no amount (spec 3 P04, T06).
    ///
    /// Save adds the new item and archives the old one in one transaction. The old item keeps its name and
    /// its records, so a past record still names the product of that time.
    func openEditorForNewProduct(_ itemID: ItemID) {
        let generation = dataGeneration
        Task {
            do {
                let stored = try await store.editorContext(for: itemID)
                guard let item = stored.item else { throw EditorOpenError.itemNotFound }
                let context = try await store.editorContext(for: nil)
                let start = ItemDraft.replacing(item, schedule: stored.schedule)
                // The copy of the old item is the start, so Cancel closes the screen with no question.
                var session = EditorSession(
                    context: context, original: start, start: start, isRestored: false, generation: generation
                )
                session.replaced = (item, stored.schedule)
                if let kept = DraftFile.load(key: session.draftKey), kept != start {
                    session = EditorSession(context: context, original: start, start: kept, isRestored: true, generation: generation)
                    session.replaced = (item, stored.schedule)
                }
                editor = session
            } catch {
                refresh()
            }
        }
    }

    /// "Add for": the edit screen of a new item for another member, with every value of the stored item (D127). Nothing is saved
    /// until the user taps Save (spec 2, 7.2). The new item has its own IDs, plan, and records. The stored item does not change.
    func openEditorForCopy(_ itemID: ItemID, for person: PersonID) {
        let generation = dataGeneration
        Task {
            do {
                let stored = try await store.editorContext(for: itemID)
                guard let item = stored.item else { throw EditorOpenError.itemNotFound }
                let context = try await store.editorContext(for: nil)
                let start = ItemDraft.copying(item, schedule: stored.schedule, for: person)
                // The copy is the start, so Cancel closes the screen with no question.
                var session = EditorSession(
                    context: context, original: start, start: start, isRestored: false, generation: generation
                )
                session.copied = (item.id, person, item.imageReference)
                // A draft that the app kept after it stopped comes back with its own IDs.
                if let kept = DraftFile.load(key: session.draftKey), kept != start {
                    session = EditorSession(context: context, original: start, start: kept, isRestored: true, generation: generation)
                    session.copied = (item.id, person, item.imageReference)
                }
                editor = session
                analytics.capture(.setupStep(.editorOpened, mode: session.mode))
            } catch {
                refresh()
            }
        }
    }

    /// Turns the reminders of an item off or on. Off keeps the item on Today and My Items, and the user can
    /// still record it (T07). A failure throws, and the store is unchanged. After a restore the store refuses
    /// the change, and the pages read again (D040).
    func setReminders(on isOn: Bool, for item: Item) async throws {
        let schedule: Schedule?
        do throws(StorageError) {
            schedule = try await store.setReminders(on: isOn, for: item.id, generation: dataGeneration)
        } catch .replaced {
            return refresh()
        }
        await finishChange(isOn ? .remindersOn : .remindersOff, schedule: schedule, mayAsk: isOn && !item.isArchived)
    }

    /// The user said yes to the one offer after a first save with a time (D091): "Remind Again" turns on for that item,
    /// two more times, 30 minutes apart. The item detail and the edit screen show it, and the user can change it there.
    /// A failure changes nothing, and the user can still turn it on in the item.
    func turnOnRemindAgain(for itemID: ItemID) {
        let now = Date()
        let generation = dataGeneration
        Task {
            let schedule: Schedule?
            do throws(StorageError) {
                schedule = try await store.setFollowUp(
                    FollowUpSetting(count: .two, interval: .minutes30), for: itemID, at: now, generation: generation
                )
            } catch .replaced {
                return refresh()
            } catch {
                reportCoreError(.save, error)
                return
            }
            await finishChange(.remindersOn, schedule: schedule, mayAsk: false)
        }
    }

    /// Archives an item, or restores it. Archive cancels the future reminders and keeps the records (T08).
    /// A failure throws, and the store is unchanged. After a restore the store refuses the change, and the pages
    /// read again (D040).
    func setArchived(_ isArchived: Bool, for itemID: ItemID) async throws {
        let result: (item: Item, schedule: Schedule?)?
        do throws(StorageError) {
            result = try await store.setArchived(isArchived, for: itemID, generation: dataGeneration)
        } catch .replaced {
            return refresh()
        }
        guard let result else {
            refresh()
            return
        }
        await finishChange(
            isArchived ? .archived : .restored,
            schedule: result.schedule,
            mayAsk: !isArchived && result.schedule?.isEnabled == true
        )
    }

    /// Asks for the one confirmation of an archive or a delete. Today, My Items, the item detail, and the
    /// archived list call it, and `RootView` shows the alert (D033).
    func askToEnd(_ kind: ItemEndRequest.Kind, itemID: ItemID, name: String) {
        endRequest = ItemEndRequest(kind: kind, itemID: itemID, name: name)
    }

    /// Runs a confirmed archive or delete. The pages change only after the commit (spec 7.2).
    func end(_ request: ItemEndRequest) {
        Task {
            do {
                switch request.kind {
                case .archive: try await setArchived(true, for: request.itemID)
                case .delete: try await deleteItem(request.itemID)
                }
            } catch {
                endFailed = true
            }
        }
    }

    /// Deletes an item with its plan and its records, in one transaction (D033). The user confirmed it, so it
    /// is not a recovery from an error (spec 7.3). A failure throws, and the store is unchanged. After a restore
    /// the store refuses the delete, and the pages read again (D040).
    ///
    /// After the commit, the kept drafts of the item go, and one run of the notification queue removes its
    /// reminders and its follow-ups. A removal that the run did not confirm gets the alert of an archive (spec 8.1).
    func deleteItem(_ itemID: ItemID) async throws {
        let deleted: (schedules: [ScheduleID], versions: [ScheduleVersionID])?
        do throws(StorageError) {
            deleted = try await store.deleteItem(itemID, generation: dataGeneration)
        } catch .replaced {
            return refresh()
        }
        guard let (schedules, versions) = deleted else {
            refresh()
            return
        }
        DraftFile.remove(key: EditorSession.editKey(of: itemID))
        DraftFile.remove(key: EditorSession.replaceKey(of: itemID))
        forgetUnconfirmed(of: itemID, versions: Set(versions))
        // The records of the item went with it (D107).
        proRecordsDidChange()
        for id in schedules {
            reminderStatus[id] = nil
            reminderCoverageEnds[id] = nil
        }
        refresh()
        forgetHistory(of: itemID)

        // An item with no schedule has no reminder and no follow-up.
        guard !schedules.isEmpty else { return }
        let now = Date()
        var isConfirmed = false
        if let deviceTimeZone = NamedTimeZone(device: .current, at: now),
           let result = try? await store.reconcileAfterDelete(at: now, deviceTimeZone: deviceTimeZone) {
            isConfirmed = result
        }
        if !isConfirmed { reminderAlerts.append(ReminderAlert(kind: .mayStillRemind)) }
    }

    /// Forgets every event of a deleted item that the store did not confirm, also one that no page shows now.
    /// Its dose is gone, so a retry has nothing to save, and no "not saved" row stays for the item (D014).
    ///
    /// An event of a planned dose names a schedule version, and each version belongs to one item.
    /// An as-needed event names the item.
    func forgetUnconfirmed(of itemID: ItemID, versions: Set<ScheduleVersionID>) {
        for (id, pending) in today.pending where versions.contains(pending.scheduleVersionID) {
            if let occurrence = pending.backfill { today.backfills[occurrence.key] = nil }
            today.pending[id] = nil
        }
        today.asNeeded.unconfirmed = today.asNeeded.unconfirmed.filter { $0.value.pending.occurrence.itemID != itemID }
        // An alert that offers a retry of such an event has nothing to send.
        let isForgotten = { (failure: TodayFailure?) in
            failure?.events.contains(where: { versions.contains($0.scheduleVersionID) }) == true
        }
        if isForgotten(today.failure) { today.failure = nil }
        if isForgotten(history.failure) { history.failure = nil }
        if today.asNeeded.failure?.pending?.occurrence.itemID == itemID { today.asNeeded.failure = nil }
        if history.asNeededFailure?.pending?.occurrence.itemID == itemID { history.asNeededFailure = nil }
    }

    /// Takes the doses of a deleted item out of the days that History keeps, so no row offers a correction
    /// of a dose that is gone. A read that started before the delete does not show, and an open History
    /// reads again.
    func forgetHistory(of itemID: ItemID) {
        history.readCount += 1
        history.days = history.days?.map { day in
            var day = day
            day.doses.removeAll { $0.itemID == itemID }
            day.asNeeded.removeAll { $0.occurrence.itemID == itemID }
            return day
        }
        history.looks[itemID] = nil
        if history.isOpen {
            loadHistory()
            loadHistoryGraph()
        }
    }

    /// After the commit: read the store again, so the pages show the change in place, then run the one
    /// notification queue, which also refreshes the follow-ups (spec 8.1). After off or archive, the reminders
    /// are gone only when the run confirmed both the series and the follow-up removals.
    private func finishChange(_ change: Change, schedule: Schedule?, mayAsk: Bool) async {
        refresh()

        guard let schedule else { return }
        let now = Date()
        let removes = change == .remindersOff || change == .archived
        var status = ReminderStatus.notSet
        if let deviceTimeZone = NamedTimeZone(device: .current, at: now),
           let state = try? await store.reconcile(
               scheduleID: schedule.id,
               at: now,
               deviceTimeZone: deviceTimeZone,
               mayAskForPermission: mayAsk,
               removesFollowUps: removes
           ) {
            status = ReminderStatus(state)
        }
        report(status, of: schedule.id, removes: removes)
    }

    private enum Change {
        case remindersOff, remindersOn, archived, restored
    }

    /// Keeps the state for the item detail. A failed reminder also gets an alert, because the page that the
    /// user sees after a save can be another one (spec 8.1). With notifications off there is no alert:
    /// Today, My Items, and the detail say it in place, and Maru does not ask again and again (T13).
    func report(_ status: ReminderStatus, of scheduleID: ScheduleID, removes: Bool) {
        reminderStatus[scheduleID] = status
        let kind: ReminderAlert.Kind? = if removes {
            [.off, .notAsked, .notificationsOff].contains(status) ? nil : .mayStillRemind
        } else {
            switch status {
            case .set, .off, .notAsked, .notificationsOff: nil
            case .tooMany: .tooMany
            case .notSet: .notSet
            case .notConfirmed: .notConfirmed
            }
        }
        if let kind { reminderAlerts.append(ReminderAlert(kind: kind)) }
        switch status {
        case .tooMany: analytics.capture(.coreError(.schedule, .tooMany))
        case .notSet: analytics.capture(.coreError(.schedule, .notSet))
        case .notConfirmed: analytics.capture(.coreError(.schedule, .notConfirmed))
        case .set, .off, .notAsked, .notificationsOff: break
        }
    }

    /// The alert of this result shows now, so it does not wait any longer.
    func reminderAlertDidShow(_ id: ReminderAlert.ID) {
        reminderAlerts.removeAll { $0.id == id }
    }

    /// A full run of the engine at a launch or a return gives the state of every schedule.
    ///
    /// The series state does not include the follow-ups. A removal that is not confirmed stays so until this
    /// run also confirms the follow-up removals, as in `AppStore.reconcile` (spec 8.1).
    func reminderRunDidEnd(_ outcome: (reminders: ReminderOutcome, followUps: FollowUpOutcome?)?) {
        guard let outcome else { return }
        let unconfirmed = outcome.followUps?.removalPending != false
            ? reminderStatus.filter { $0.value == .notConfirmed }.keys.map(\.self) : []
        reminderStatus = outcome.reminders.schedules.mapValues(ReminderStatus.init)
        reminderCoverageEnds = outcome.reminders.coverageEnds
        for id in unconfirmed where reminderStatus[id] == .off || reminderStatus[id] == .set {
            reminderStatus[id] = .notConfirmed
        }
    }
}
