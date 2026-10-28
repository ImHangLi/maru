import Foundation
import MaruCore
import MaruDatabase

extension TodaySnapshot {
    /// Generates the occurrences around `now`, and reads what the rows of today need (spec 9).
    /// The app and the widgets use it, so they show the same today (D048).
    ///
    /// It reads no older intake history (spec 7.3). The as-needed card is not part of it.
    /// - Parameters:
    ///   - items: Every item of the store.
    ///   - family: The members, so each row knows its owner for a text (D123).
    ///   - generation: The generation of the data that the caller read (D040).
    /// - Returns: The snapshot, and the occurrences that the run gave, also those of yesterday and tomorrow.
    static func load(
        from store: LocalStore,
        items: [Item],
        family: Family,
        remindersOff: Set<ItemID>,
        at now: Date,
        deviceTimeZone: NamedTimeZone,
        generation: Int
    ) async throws(StorageError) -> (snapshot: TodaySnapshot, occurrences: [Occurrence]) {
        let run = try await store.generate(at: now, deviceTimeZone: deviceTimeZone, generation: generation)
        let itemIDs = try await store.itemIDsBySlot()
        // An archived item leaves Today, also with a record of today. The record stays in the history (T08).
        let looks = Dictionary(uniqueKeysWithValues: items.filter { !$0.isArchived }.map {
            ($0.id, ItemLook(
                itemID: $0.id, personID: $0.personID, name: $0.name, form: $0.form, color: $0.color,
                owner: family.owner(of: $0),
                remindersOff: remindersOff.contains($0.id), imageReference: $0.imageReference
            ))
        })
        let todays = Self.today(run.occurrences, at: now)
        let snapshot = TodaySnapshot(
            now: now,
            timeZone: deviceTimeZone,
            occurrences: run.occurrences,
            planZones: run.planZones,
            looks: itemIDs.compactMapValues { looks[$0] },
            doses: try await store.doses(of: Set(todays.map(\.scheduleVersionID))),
            records: try await store.records(of: todays.map(\.id))
        )
        return (snapshot, run.occurrences)
    }
}
