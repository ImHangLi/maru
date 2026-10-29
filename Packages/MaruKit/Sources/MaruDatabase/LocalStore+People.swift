import Foundation
import GRDB
import MaruCore

extension LocalStore {
    /// Every member of the Family, archived or not, in the order of the first save (D121). The first member is `me`.
    public func people() async throws(StorageError) -> [Person] {
        try await read { db in try Self.fetchPeople(db) }
    }

    /// Inserts a member, or updates the name, the kind, the animal, the color, and the photo of the stored member with the same ID (D121, D124).
    ///
    /// The store never reads Maru Pro: the app checks it before a new member (D122). `save` never changes the archive state.
    /// Use `archive(person:)` and `restore(person:)` for that, because an archive moves the items of the member too (D125).
    /// `me` stays `me`, and a second `me` is `conflict`. A member that does not load again as the same value is `invalidData`.
    public func save(_ person: Person, generation: Int = 0) async throws(StorageError) {
        try await save(person, mustExist: false, generation: generation)
    }

    /// Updates an existing member. A missing member cannot become a new member through the free edit path (D122).
    public func update(_ person: Person, generation: Int = 0) async throws(StorageError) {
        try await save(person, mustExist: true, generation: generation)
    }

    private func save(_ person: Person, mustExist: Bool, generation: Int) async throws(StorageError) {
        try await write(generation: generation) { db in
            let stored = try Self.fetchPerson(db, id: person.id)
            if mustExist, stored == nil { throw StorageError.conflict }
            if let stored, (stored.kind == .me) != (person.kind == .me) { throw StorageError.conflict }
            if stored == nil, person.kind == .me { throw StorageError.conflict }
            try db.execute(
                sql: """
                    INSERT INTO person (id, kind, name, symbol, color, imageReference, archivedAt) VALUES (?, ?, ?, ?, ?, ?, NULL)
                    ON CONFLICT (id) DO UPDATE SET
                        kind = excluded.kind, name = excluded.name, symbol = excluded.symbol, color = excluded.color,
                        imageReference = excluded.imageReference
                    """,
                arguments: [
                    person.id.text, person.kind.rawValue, person.name, person.symbol?.rawValue, person.color?.rawValue,
                    person.imageReference,
                ]
            )
            guard var saved = try Self.fetchPerson(db, id: person.id) else { throw StorageError.invalidData }
            saved.archivedAt = person.archivedAt
            guard saved == person else { throw StorageError.invalidData }
        }
    }

    /// Archives a member and every active item of the member in one transaction, with one instant (D125, D084).
    /// The reminders of those items stop with the next run. History keeps the past doses (D091).
    ///
    /// The last active member cannot be archived: it is `conflict`. A member that is archived already, or that the store does not
    /// have, changes nothing. `at` is the instant of the archive.
    public func archive(person id: PersonID, at now: Date = Date(), generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            guard let person = try Self.fetchPerson(db, id: id), !person.isArchived else { return }
            guard try Self.activeCount(db) > 1 else { throw StorageError.conflict }
            try db.execute(sql: "UPDATE person SET archivedAt = ? WHERE id = ?", arguments: [now.storedSeconds, id.text])
            try db.execute(
                sql: "UPDATE item SET isArchived = 1, archivedAt = ? WHERE personID = ? AND isArchived = 0",
                arguments: [now.storedSeconds, id.text]
            )
        }
    }

    /// Restores a member and the items that the archive of the member archived, in one transaction (D125). An item that the user
    /// archived on its own, before or after, has another instant and stays archived.
    public func restore(person id: PersonID, generation: Int = 0) async throws(StorageError) {
        try await write(generation: generation) { db in
            guard let person = try Self.fetchPerson(db, id: id), let archivedAt = person.archivedAt else { return }
            try db.execute(sql: "UPDATE person SET archivedAt = NULL WHERE id = ?", arguments: [id.text])
            try db.execute(
                sql: "UPDATE item SET isArchived = 0, archivedAt = NULL WHERE personID = ? AND isArchived = 1 AND archivedAt = ?",
                arguments: [id.text, archivedAt.storedSeconds]
            )
        }
    }

    /// Deletes a member with every item of the member and every record of those items, in one transaction (D125, D033).
    /// The user asks for this delete and confirms it. It is not a recovery from an error (spec 7.3).
    ///
    /// `me` cannot be deleted, and no delete leaves no active member: both are `conflict`, and nothing changes. A failure rolls
    /// back every delete.
    ///
    /// - Returns: The IDs of the deleted schedules and of their versions, or `nil` when the store has no such member.
    @discardableResult
    public func delete(
        person id: PersonID, generation: Int = 0
    ) async throws(StorageError) -> (schedules: [ScheduleID], versions: [ScheduleVersionID])? {
        try await write(generation: generation) { db in
            guard let person = try Self.fetchPerson(db, id: id) else { return nil }
            let active = try Self.activeCount(db)
            guard person.kind != .me, person.isArchived || active > 1 else { throw StorageError.conflict }
            var schedules: [ScheduleID] = []
            var versions: [ScheduleVersionID] = []
            for text in try String.fetchAll(db, sql: "SELECT id FROM item WHERE personID = ? ORDER BY rowid", arguments: [id.text]) {
                if let deleted = try Self.deleteRows(ofItem: ItemID(text: text), db) {
                    schedules += deleted.schedules
                    versions += deleted.versions
                }
            }
            try db.execute(sql: "DELETE FROM person WHERE id = ?", arguments: [id.text])
            return (schedules, versions)
        }
    }

    /// Gives an item to another member (D121). The records, the schedules, and the history of the item move with it. This is a
    /// correction of a wrong setup, so no record is copied or rewritten.
    ///
    /// `ownerChangedAt` becomes `now`. A quick action that a reminder, a widget, the Watch, or a Live Activity listed before it
    /// records nothing (D123). An unknown item or member, and an active item for an archived member, are `conflict`. The same owner
    /// changes nothing.
    public func setOwner(
        _ person: PersonID, of itemID: ItemID, at now: Date? = nil, generation: Int = 0
    ) async throws(StorageError) {
        try await write(generation: generation) { db in
            // The clock in the transaction, not before the wait for the writer: a read that starts during the wait must not get a
            // list instant after the change (D123).
            let now = now ?? Date()
            guard var item = try Self.fetchItem(db, id: itemID), try Self.fetchPerson(db, id: person) != nil else {
                throw StorageError.conflict
            }
            guard item.personID != person else { return }
            item.personID = person
            try Self.upsert(item, at: now, db)
        }
    }

    static func fetchPeople(_ db: Database) throws -> [Person] {
        try Row.fetchAll(db, sql: "SELECT * FROM person ORDER BY rowid").map(decodePerson)
    }

    static func fetchPerson(_ db: Database, id: PersonID) throws -> Person? {
        try Row.fetchOne(db, sql: "SELECT * FROM person WHERE id = ?", arguments: [id.text]).map(decodePerson)
    }

    private static func activeCount(_ db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM person WHERE archivedAt IS NULL") ?? 0
    }

    static func decodePerson(_ row: Row) throws -> Person {
        try named(.personRow) {
            let symbol: String? = try row.decode(forColumn: "symbol")
            let color: String? = try row.decode(forColumn: "color")
            let archivedAt: Double? = try row.decode(forColumn: "archivedAt")
            return try Person(
                id: PersonID(text: row.decode(forColumn: "id")),
                kind: PersonKind(text: row.decode(forColumn: "kind")),
                name: row.decode(forColumn: "name"),
                symbol: symbol.map { try PetSymbol(text: $0) },
                color: color.map { try ItemColor(text: $0) },
                imageReference: row.decode(forColumn: "imageReference"),
                archivedAt: archivedAt.map(Date.init(storedSeconds:))
            )
        }
    }
}
