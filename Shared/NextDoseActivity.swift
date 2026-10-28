import ActivityKit
import AppIntents
import Foundation
import os

/// "Next Dose on Lock Screen", a Live Activity of Maru Pro (D110). The app starts, updates, and ends it. The widget
/// extension draws it. Maru has no server, so no push changes it: only the app process does.
struct NextDoseAttributes: ActivityAttributes, Sendable {
    /// What the activity shows. It has the item names only when "Show Names in Reminders" is on (D029).
    struct ContentState: Codable, Hashable, Sendable {
        /// The part of the day of the doses, as its link name (`DayPart.linkName`).
        var part: String
        /// The planned time of the doses.
        var plannedAt: Date
        /// The identifier of the time zone that writes the planned time.
        var timeZone: String
        /// The item names in the order of Today. Empty when the names are hidden.
        var names: [String]
        var count: Int
        /// The doses that "Taken" records. Each occurrence has the schedule version at the same index.
        var occurrenceIDs: [String]
        var scheduleVersionIDs: [String]
        /// The restore epoch of the data that the app read (D040).
        var epoch: Int
        /// The planned time was past at the update. The stale date is then the end of the day.
        var isOverdue: Bool
        /// "Taken" did not get a confirmed commit. The next update clears it.
        var isNotConfirmed = false
    }

    /// The start of the activity. The system ends an activity 8 hours after its start, so the app starts a new one
    /// when it comes to the front.
    var startedAt: Date
}

/// The "Taken" button of the Live Activity (D110).
///
/// The app and the widget extension both compile this type. A `LiveActivityIntent` runs in the app process, also in the
/// background. There the model records the doses with the record transaction and its checks. The intent holds no
/// health data: the IDs of the doses, their schedule versions, and the restore epoch.
struct TakeNextDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Record a Dose"
    /// Only the Live Activity runs it, so Shortcuts does not offer it.
    static var isDiscoverable: Bool { false }
    /// The rule of the "Taken" action of a reminder on the iPhone: a person who holds a locked iPhone records nothing (D034).
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Dose")
    var occurrenceIDs: [String]

    @Parameter(title: "Plan")
    var scheduleVersionIDs: [String]

    @Parameter(title: "Data")
    var epoch: Int

    init() {}

    init(_ state: NextDoseAttributes.ContentState) {
        occurrenceIDs = state.occurrenceIDs
        scheduleVersionIDs = state.scheduleVersionIDs
        epoch = state.epoch
    }

    func perform() async throws -> some IntentResult {
        // The widget extension has no hook. A run there records nothing and shows no success.
        guard let run = TakeNextDoseHook.run.withLock({ $0 }) else { throw TakeDoseError.notRunningInApp }
        await run(self)
        return .result()
    }
}

/// The app sets the code of `perform()` when it starts. The widget extension never sets it.
enum TakeNextDoseHook {
    static let run = OSAllocatedUnfairLock<(@Sendable (TakeNextDoseIntent) async -> Void)?>(initialState: nil)

    static func install(_ code: @escaping @Sendable (TakeNextDoseIntent) async -> Void) {
        run.withLock { $0 = code }
    }
}
