import AppIntents
import Foundation
import os

/// The tap on a gray capsule of the "Record Dose" widget (D048).
///
/// The widget and the app both compile this type. The app adds the conformance to `ForegroundContinuableIntent`
/// in `App/TakeDoseIntent+App.swift`, so the system runs `perform()` in the app process. There the one model
/// records the dose with the record transaction, and it runs the reminders (D047). The widget process never writes
/// the database for a record. It holds no health data in the intent: two IDs and a counter.
struct TakeDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Record a Dose"

    /// The occurrence that the widget showed, as the text of its ID.
    @Parameter(title: "Dose")
    var occurrenceID: String

    /// The schedule version that the occurrence had. A changed plan makes the record fail, and Maru opens.
    @Parameter(title: "Plan")
    var scheduleVersionID: String

    /// The restore epoch of the data that the widget read. A restore changes it, so an old button records nothing.
    @Parameter(title: "Data")
    var epoch: Int

    /// The instant of the widget read, as seconds since 2001-01-01 UTC. The store refuses the dose when its item changed its owner
    /// after it (D123).
    @Parameter(title: "Read")
    var readAt: Double

    init() {}

    init(occurrenceID: String, scheduleVersionID: String, epoch: Int, readAt: Date) {
        self.occurrenceID = occurrenceID
        self.scheduleVersionID = scheduleVersionID
        self.epoch = epoch
        self.readAt = readAt.timeIntervalSinceReferenceDate
    }

    func perform() async throws -> some IntentResult {
        // The widget process has no hook. A run there records nothing and shows no success.
        guard let run = TakeDoseHook.run.withLock({ $0 }) else { throw TakeDoseError.notRunningInApp }
        try await run(self)
        return .result()
    }
}

enum TakeDoseError: Error {
    case notRunningInApp
}

/// The app sets the code of `perform()` when it starts. The widget process never sets it.
enum TakeDoseHook {
    static let run = OSAllocatedUnfairLock<(@Sendable (TakeDoseIntent) async throws -> Void)?>(initialState: nil)

    static func install(_ code: @escaping @Sendable (TakeDoseIntent) async throws -> Void) {
        run.withLock { $0 = code }
    }
}
