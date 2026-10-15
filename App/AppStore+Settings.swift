import Foundation
import MaruCore
import MaruDatabase

/// What the reminder rows of Settings need from the store (D085).
extension AppStore {
    /// The active items that have a time.
    func timedItems() async throws(StorageError) -> [Item] {
        try await open().timedItems()
    }

    /// One transaction for one reminder option of every active item that has a time. It returns the number of
    /// items that changed. `generation` is the generation of the data that the screen read (D040).
    func apply(_ change: ReminderOptionChange, at now: Date, generation: Int) async throws(StorageError) -> Int {
        try await open().apply(change, toTimedItemsAt: now, generation: generation)
    }
}
