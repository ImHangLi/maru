import Foundation
import MaruCore
import MaruDatabase

/// One open edit screen: the stored values it started from, and the draft it shows first.
struct EditorSession: Identifiable {
    let id = UUID()
    let context: EditorContext
    /// The draft with no change by the user. "Discard changes?" compares with it (spec 3 P03).
    let original: ItemDraft
    /// The draft that the screen shows first: the original, or a draft that the app kept after it stopped.
    let start: ItemDraft
    let isRestored: Bool
    /// The generation of the data that the screen read (D040). A save after a restore writes nothing.
    let generation: Int
    /// The item that a save replaces, with its schedule (T06). The draft is then a new item.
    var replaced: (item: Item, schedule: Schedule?)?
    /// For the duration bucket of the usage statistics (D077). It is not stored, and no clock time leaves the device.
    let openedAt = Date()

    var isNew: Bool { context.item == nil }

    var mode: AnalyticsEvent.EditorMode {
        replaced != nil ? .replace : isNew ? .new : .edit
    }

    /// The plan whose zone a medication keeps (spec 8.5): the stored plan, or the plan of the replaced item.
    var zoneSchedule: Schedule? { context.schedule ?? replaced?.schedule }

    /// The name of the draft file: one for a new item, one for each item in edit or in replacement.
    var draftKey: String {
        if let replaced { return Self.replaceKey(of: replaced.item.id) }
        return context.item.map { Self.editKey(of: $0.id) } ?? "new"
    }

    static func editKey(of itemID: ItemID) -> String { "item-\(itemID.rawValue.uuidString)" }
    static func replaceKey(of itemID: ItemID) -> String { "replace-\(itemID.rawValue.uuidString)" }
}

enum EditorOpenError: Error {
    case itemNotFound
}

extension AppModel {
    /// Opens the edit screen for a new item (`nil`) or for a stored item (spec 3 P03).
    func openEditor(for itemID: ItemID?) {
        let generation = dataGeneration
        Task {
            do {
                let context = try await store.editorContext(for: itemID)
                if itemID != nil, context.item == nil { throw EditorOpenError.itemNotFound }
                let original = context.item.map { ItemDraft(item: $0, schedule: context.schedule) }
                    ?? ItemDraft(color: context.newItemColor, reminders: context.newItemReminders)
                var session = EditorSession(
                    context: context, original: original, start: original, isRestored: false, generation: generation
                )
                if var kept = DraftFile.load(key: session.draftKey) {
                    // A draft of version 1.0 has no reminder options. It keeps the options of the stored item.
                    if kept.hasReminderOptions != true {
                        kept.followUp = original.followUp
                        kept.alarm = original.alarm
                        kept.hasReminderOptions = true
                    }
                    if kept != original {
                        session = EditorSession(
                            context: context, original: original, start: kept, isRestored: true, generation: generation
                        )
                    }
                }
                editor = session
                analytics.capture(.setupStep(.editorOpened, mode: session.mode))
            } catch {
                // The list or Today shows the state of the store. The edit screen does not open on stale data.
                refresh()
            }
        }
    }

    /// Ends the edit screen with no save, and removes its kept draft.
    func discardEditor() {
        if let editor { DraftFile.remove(key: editor.draftKey) }
        editor = nil
    }

    /// Saves the draft in one transaction. After the commit it closes the screen, so the list shows the item
    /// in place, and then runs the reminder engine (spec 8.1). Asking for the notification permission comes
    /// only with a reminder that the user confirmed with this save (spec 2.2).
    ///
    /// A failure throws and leaves the screen open with the draft, and the store unchanged. After a restore the
    /// store refuses the save, the screen closes, and the pages read again (D040).
    ///
    /// A new photo is a new file, written before the transaction. The old file goes after the commit, and
    /// the new file goes when the transaction fails. So a failure leaves the stored photo as it was (D056).
    func save(
        _ draft: ItemDraft,
        in session: EditorSession,
        photo: PhotoState.Edit = .unchanged,
        nameSource: AnalyticsEvent.NameSource = .typed,
        usedCompletion: Bool = false
    ) async throws {
        let now = Date()
        let deviceTimeZone = NamedTimeZone(device: .current, at: now)
        let built = try draft.build(
            item: session.context.item,
            schedule: session.context.schedule,
            keptZoneFrom: session.zoneSchedule,
            now: now,
            deviceTimeZone: deviceTimeZone
        )
        var item = built.item
        let schedule = built.schedule
        let storedPhoto = session.context.item?.imageReference
        var newPhoto: String?
        switch photo {
        case .unchanged: break
        case .removed: item.imageReference = nil
        case let .replaced(choice):
            newPhoto = try await store.writePhoto(choice.chosen.data, fileExtension: choice.chosen.fileExtension)
            item.imageReference = newPhoto
        }
        do throws(StorageError) {
            if let replaced = session.replaced {
                try await store.replace(replaced.item.id, with: item, schedule: schedule, generation: session.generation)
            } else {
                try await store.save(item, schedule: schedule, generation: session.generation)
            }
        } catch .replaced {
            // A restore replaced the data that the screen read. The draft belongs to the old data.
            await store.removePhoto(newPhoto)
            DraftFile.remove(key: session.draftKey)
            if editor?.id == session.id { editor = nil }
            return refresh()
        } catch {
            await store.removePhoto(newPhoto)
            reportCoreError(.save, error)
            throw error
        }

        if storedPhoto != item.imageReference { await store.removePhoto(storedPhoto) }
        DraftFile.remove(key: session.draftKey)
        savedEditor = session.id
        if editor?.id == session.id { editor = nil }
        refresh()
        analytics.capture(.itemSaved(AnalyticsEvent.ItemSetup(
            mode: session.mode,
            hasReminder: schedule != nil,
            hasAlarm: item.alarm,
            hasFollowUp: item.followUp != nil,
            hasAmount: schedule?.versions.last?.dose != nil,
            hasNote: item.intakeNote != nil,
            hasPhoto: item.imageReference != nil,
            nameSource: session.isNew ? nameSource : nil,
            usedCompletion: usedCompletion,
            isFirstItem: session.isNew && session.replaced == nil && session.context.itemNames.isEmpty,
            duration: Date().timeIntervalSince(session.openedAt)
        )))
        offerAnalyticsNotice()

        // A replacement with no time still runs the queue: the archived old item can hold a series and
        // follow-ups. The result then reports the removal of those.
        let removed = schedule == nil ? session.replaced?.schedule : nil
        guard let reported = schedule ?? removed else { return }
        var status = ReminderStatus.notSet
        if let deviceTimeZone,
           let state = try? await store.reconcile(
               scheduleID: reported.id,
               at: now,
               deviceTimeZone: deviceTimeZone,
               mayAskForPermission: schedule?.isEnabled == true && !item.isArchived,
               removesFollowUps: session.replaced != nil
           ) {
            status = ReminderStatus(state)
        }
        report(status, of: reported.id, removes: removed != nil)
        offerRemindAgain(for: item, session: session, hasTime: schedule != nil)
    }

    /// The first save of an item with a time offers "Remind Again" one time, as a plain question. It turns on nothing by
    /// itself, and it never comes back after it showed or when the user chose it already (D091, spec 2.1).
    private func offerRemindAgain(for item: Item, session: EditorSession, hasTime: Bool) {
        let key = "reminders.remindAgainOffered"
        let defaults = UserDefaults.standard
        guard hasTime, session.isNew, session.replaced == nil, item.followUp == nil, !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        remindAgainOffer = item.id
    }

    /// The first tap on the "Alarm" switch asks the system for the alarm permission (D079). `true` when alarms can ring.
    func allowAlarms() async -> Bool {
        await AlarmSupport.requestAuthorization()
    }

    /// The edit screen closed. A close after a save sends nothing more, because the save sent `item_saved`.
    func editorDidClose(_ session: EditorSession, hadChanges: Bool) {
        if savedEditor == session.id {
            savedEditor = nil
            return
        }
        analytics.capture(.editorClosed(
            mode: session.mode, hadChanges: hadChanges, duration: Date().timeIntervalSince(session.openedAt)
        ))
    }

    /// A step of the label scan on the edit screen (D077).
    func editorStep(_ step: AnalyticsEvent.SetupStep, in session: EditorSession) {
        analytics.capture(.setupStep(step, mode: session.mode))
    }

    /// The scanner could not run, after the camera permission.
    func scanDidFail() {
        analytics.capture(.coreError(.scan, .failed))
    }
}
