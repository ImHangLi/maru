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

    var isNew: Bool { context.item == nil }

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
                    ?? ItemDraft(color: context.newItemColor)
                var session = EditorSession(
                    context: context, original: original, start: original, isRestored: false, generation: generation
                )
                if let kept = DraftFile.load(key: session.draftKey), kept != original {
                    session = EditorSession(
                        context: context, original: original, start: kept, isRestored: true, generation: generation
                    )
                }
                editor = session
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
    func save(_ draft: ItemDraft, in session: EditorSession) async throws {
        let now = Date()
        let deviceTimeZone = NamedTimeZone(device: .current, at: now)
        let (item, schedule) = try draft.build(
            item: session.context.item,
            schedule: session.context.schedule,
            keptZoneFrom: session.zoneSchedule,
            now: now,
            deviceTimeZone: deviceTimeZone
        )
        do throws(StorageError) {
            if let replaced = session.replaced {
                try await store.replace(replaced.item.id, with: item, schedule: schedule, generation: session.generation)
            } else {
                try await store.save(item, schedule: schedule, generation: session.generation)
            }
        } catch .replaced {
            // A restore replaced the data that the screen read. The draft belongs to the old data.
            DraftFile.remove(key: session.draftKey)
            if editor?.id == session.id { editor = nil }
            return refresh()
        }

        DraftFile.remove(key: session.draftKey)
        if editor?.id == session.id { editor = nil }
        refresh()

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
    }
}
