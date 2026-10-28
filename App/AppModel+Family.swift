import Foundation
import MaruCore
import MaruDatabase

/// Why a Family operation did nothing.
enum FamilyError: Error, Equatable {
    /// A free user tried to add a member. The paywall shows (D122).
    case needsPro
}

extension AppModel {
    /// Adds a person or a pet (D121). Maru Pro adds a member. A free user gets the paywall with the source `family`, and nothing is
    /// saved (D122). A member that exists never locks: every other operation here is free, also after Pro ends.
    ///
    /// The store never reads Pro, so this is the one gate. The UI calls it and shows the add sheet again after a purchase.
    func addMember(_ person: Person) async throws {
        guard await confirmedPro() else {
            presentPaywall(reason: .family)
            throw FamilyError.needsPro
        }
        try await changeFamily { store, generation in try await store.savePerson(person, generation: generation) }
    }

    /// Changes the name, the kind, the animal, or the photo of a member. A replaced photo file goes after the save (D124).
    /// The UI writes a new photo with `AppStore.writePhoto` first, as the item editor does (D056).
    func updateMember(_ person: Person) async throws {
        guard let existing = try await store.people().first(where: { $0.id == person.id }) else {
            throw StorageError.conflict
        }
        let stored = existing.imageReference
        try await changeFamily { store, generation in try await store.updatePerson(person, generation: generation) }
        if let stored, stored != person.imageReference { await store.removePhoto(stored) }
    }

    /// Archives a member with its items. The last active member cannot be archived (D125).
    func archiveMember(_ id: PersonID) async throws {
        try await changeFamily { store, generation in try await store.archivePerson(id, generation: generation) }
    }

    /// Restores a member with the items that its archive archived (D125).
    func restoreMember(_ id: PersonID) async throws {
        try await changeFamily { store, generation in try await store.restorePerson(id, generation: generation) }
    }

    /// Gives an item to another member. The records move with it, and an old quick action records nothing (D121, D123).
    func moveItem(_ itemID: ItemID, to person: PersonID) async throws {
        try await changeFamily { store, generation in try await store.setOwner(person, of: itemID, generation: generation) }
    }

    /// Deletes a member with every item and every record of the member, in one transaction (D125, D033). The user confirmed it,
    /// so it is not a recovery from an error (spec 7.3). `me` and the last active member cannot be deleted.
    func deleteMember(_ id: PersonID) async throws {
        let items = (try? await store.itemIDs(of: id)) ?? []
        let deleted: (schedules: [ScheduleID], versions: [ScheduleVersionID])?
        do throws(StorageError) {
            deleted = try await store.deletePerson(id, generation: dataGeneration)
        } catch .replaced {
            return refresh()
        }
        guard let (schedules, versions) = deleted else { return refresh() }
        for itemID in items {
            DraftFile.remove(key: EditorSession.editKey(of: itemID))
            DraftFile.remove(key: EditorSession.replaceKey(of: itemID))
            forgetUnconfirmed(of: itemID, versions: Set(versions))
            forgetHistory(of: itemID)
        }
        proRecordsDidChange()
        for id in schedules {
            reminderStatus[id] = nil
            reminderCoverageEnds[id] = nil
        }
        refresh()
        guard !schedules.isEmpty else { return }
        let now = Date()
        var isConfirmed = false
        if let deviceTimeZone = NamedTimeZone(device: .current, at: now),
           let result = try? await store.reconcileAfterDelete(at: now, deviceTimeZone: deviceTimeZone) {
            isConfirmed = result
        }
        if !isConfirmed { reminderAlerts.append(ReminderAlert(kind: .mayStillRemind)) }
    }

    /// One write, then the pages read again and one run of the reminders follows: a name, an owner, or an archive changes the text
    /// and the plan (D084, D123). After a restore the store refuses the write, and the pages read again (D040).
    private func changeFamily(_ write: (AppStore, Int) async throws -> Void) async throws {
        do {
            try await write(store, dataGeneration)
        } catch StorageError.replaced {
            return refresh()
        }
        refresh()
        refreshReminders()
    }
}

extension AppStore {
    func savePerson(_ person: Person, generation: Int) async throws(StorageError) {
        try await open().save(person, generation: generation)
    }

    func updatePerson(_ person: Person, generation: Int) async throws(StorageError) {
        try await open().update(person, generation: generation)
    }

    func archivePerson(_ id: PersonID, generation: Int) async throws(StorageError) {
        try await open().archive(person: id, generation: generation)
    }

    func restorePerson(_ id: PersonID, generation: Int) async throws(StorageError) {
        try await open().restore(person: id, generation: generation)
    }

    func setOwner(_ person: PersonID, of itemID: ItemID, generation: Int) async throws(StorageError) {
        try await open().setOwner(person, of: itemID, generation: generation)
    }

    /// Deletes a member with its items, and then the photo files of the items and of the member (D056, D124, D125).
    func deletePerson(
        _ id: PersonID, generation: Int
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        let store = try open()
        let photos = try await store.items().filter { $0.personID == id }.map(\.imageReference)
            + store.people().filter { $0.id == id }.map(\.imageReference)
        let deleted = try await store.delete(person: id, generation: generation)
        if deleted != nil { photos.forEach(ItemPhotos.remove) }
        return deleted
    }

    func itemIDs(of person: PersonID) async throws(StorageError) -> [ItemID] {
        try await open().items().filter { $0.personID == person }.map(\.id)
    }
}
