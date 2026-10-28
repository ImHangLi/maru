import ActivityKit
import AppIntents
import Foundation
import os

/// "Next Dose on Lock Screen", a Live Activity of Maru Pro (D110). The app starts, updates, and ends it. The widget
/// extension draws it. Maru has no server, so no push changes it: only the app process does.
struct NextDoseAttributes: ActivityAttributes, Sendable {
    /// What the activity shows. It has the item names only when "Show Names in Reminders" is on (D029).
    ///
    /// ActivityKit limits the content to 4 KB, so the state holds a short token in place of the doses, and at most
    /// three names in a limit of bytes. The app keeps the doses of the token on the device.
    struct ContentState: Codable, Hashable, Sendable {
        /// The part of the day of the doses, as its link name (`DayPart.linkName`).
        var part: String
        /// The planned time of the doses.
        var plannedAt: Date
        /// The identifier of the time zone that writes the planned time.
        var timeZone: String
        /// The first item names in the order of Today. Empty when the names are hidden.
        var names: [String]
        /// The number of doses. It can be more than the names.
        var count: Int
        /// The doses that "Taken" records. The app finds them, their schedule versions, and the restore epoch from it.
        var token: String
        /// The end of the day of the doses. It is also the stale date. After it, the activity asks to open Maru.
        var expiresAt: Date
        /// "Taken" did not get a confirmed commit. The next update clears it.
        var isNotConfirmed = false
        /// The doses belong to one member of the Family, so the button records for one member only (D123).
        /// A state from before the Family has no value and keeps the button.
        var canRecord: Bool? = nil
    }

    /// The start of the activity. The system ends an activity 8 hours after its start, so the app starts a new one
    /// when it comes to the front.
    var startedAt: Date
}

/// The "Taken" button of the Live Activity (D110).
///
/// The app and the widget extension both compile this type. A `LiveActivityIntent` runs in the app process, also in the
/// background. There the model records the doses with the record transaction and its checks. The intent holds no
/// health data: only the token of the doses that the activity shows.
struct TakeNextDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Record a Dose"
    /// Only the Live Activity runs it, so Shortcuts does not offer it.
    static var isDiscoverable: Bool { false }
    /// The rule of the "Taken" action of a reminder on the iPhone: a person who holds a locked iPhone records nothing (D034).
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Dose")
    var token: String

    init() {}

    init(_ state: NextDoseAttributes.ContentState) {
        token = state.token
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
