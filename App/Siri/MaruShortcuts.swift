import AppIntents
import MaruCore
import MaruDatabase
import SwiftUI

// Siri and Shortcuts (D108). Each intent runs in the app process, in the background, and calls an operation of the one
// model (spec 6). The two questions only read. "Record my doses" records with the record transaction after a confirmation,
// and it says "recorded" only after the commit (spec 7.2). Nothing goes to analytics.

/// The phrases of the three App Shortcuts. `App/AppShortcuts.xcstrings` has them in the other languages.
struct MaruShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextDoseIntent(),
            phrases: [
                "What do I take next in \(.applicationName)",
                "What's next in \(.applicationName)",
                "Next dose in \(.applicationName)",
            ],
            shortTitle: "Next Dose",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: LastDoseIntent(),
            phrases: [
                "Did I take my \(\.$item) in \(.applicationName)",
                "When did I last take \(\.$item) in \(.applicationName)",
                "Last dose of \(\.$item) in \(.applicationName)",
                "Check my last dose in \(.applicationName)",
            ],
            shortTitle: "Last Dose",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: RecordDueDosesIntent(),
            phrases: [
                "Record my doses in \(.applicationName)",
                "Log my doses in \(.applicationName)",
            ],
            shortTitle: "Record Doses",
            systemImageName: "pills"
        )
    }
}

/// An active item, so Siri can pick it by name. It holds the ID and the name, and nothing else.
struct ItemEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Item"
    static let defaultQuery = ItemEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// The active items of the store. An archived item is not offered.
struct ItemEntityQuery: EntityStringQuery {
    func entities(for identifiers: [UUID]) async throws -> [ItemEntity] {
        try await Self.items().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ItemEntity] {
        try await Self.items().filter { $0.name.localizedStandardContains(string) }
    }

    func suggestedEntities() async throws -> [ItemEntity] {
        try await Self.items()
    }

    @MainActor
    private static func items() async throws -> [ItemEntity] {
        do {
            return try await AppModel.shared.siriItems().map { ItemEntity(id: $0.id.rawValue, name: $0.name) }
        } catch {
            throw SiriProblem.unreadable
        }
    }
}

/// "What do I take next": the next open doses of today, spoken and in a snippet. It records nothing.
/// A locked iPhone asks for an unlock first, so a person who holds it can not hear the names.
struct NextDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Dose"
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let next: SiriNext
        do {
            next = try await AppModel.shared.siriNext()
        } catch {
            throw SiriProblem.unreadable
        }
        switch next {
        case let .next(doses):
            let names = doses.doses.map(\.name).formatted(.list(type: .and))
            let time = doses.time.formatted(.rowTime(in: doses.timeZone))
            return .result(dialog: "Next up: \(names), planned for \(time).", view: NextDoseSnippet(next: doses, message: nil))
        case .allDone:
            let message: LocalizedStringResource = "All done for today. Nice work."
            return .result(dialog: IntentDialog(message), view: NextDoseSnippet(next: nil, message: message))
        case .nothingPlanned:
            let message: LocalizedStringResource = "Nothing to take today. Enjoy it."
            return .result(dialog: IntentDialog(message), view: NextDoseSnippet(next: nil, message: message))
        }
    }
}

/// "Did I take my …": the newest taken record of one item, with its time. It records nothing.
/// A locked iPhone asks for an unlock first, as for "Next Dose".
struct LastDoseIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Dose of an Item"
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Item", requestValueDialog: "Which item?")
    var item: ItemEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Last dose of \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let last: LastDose?
        do {
            last = try await AppModel.shared.siriLastDose(of: ItemID(item.id))
        } catch {
            throw SiriProblem.unreadable
        }
        guard let last else {
            return .result(dialog: "Maru has no taken record for \(item.name) yet.")
        }
        let time = last.takenAt.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(last.takenAt) {
            return .result(dialog: "Your last record for \(last.name): taken today at \(time).")
        }
        if calendar.isDateInYesterday(last.takenAt) {
            return .result(dialog: "Your last record for \(last.name): taken yesterday at \(time).")
        }
        let date = last.takenAt.formatted(date: .abbreviated, time: .omitted)
        return .result(dialog: "Your last record for \(last.name): taken on \(date) at \(time).")
    }
}

/// "Record my doses": records the open doses of the part of the day of the clock as taken now, after a confirmation.
/// A locked iPhone asks for an unlock first, as the "Taken" action of a reminder does (D034, D066).
struct RecordDueDosesIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Due Doses"
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let due: SiriDueDoses
        do {
            due = try await model.siriDueDoses()
        } catch {
            throw SiriProblem.unreadable
        }
        guard !due.entries.isEmpty else {
            return .result(dialog: "Nothing is due right now. You’re all set.")
        }
        let names = due.names.formatted(.list(type: .and))
        // A "Cancel" throws, and nothing is recorded.
        try await requestConfirmation(result: .result(dialog: "Record as taken now: \(names)?"))
        guard await model.recordFromSiri(due) else { throw SiriProblem.notRecorded }
        return .result(dialog: "Recorded as taken: \(names).")
    }
}

/// What Siri says when Maru can not read or record. The text names no item.
enum SiriProblem: Error, CustomLocalizedStringResourceConvertible {
    /// The database did not open or a read failed. After a restart and before the first unlock, file protection is the
    /// usual cause (D066).
    case unreadable
    /// The record transaction gave no commit. Nothing is recorded, or the event waits on Today for a retry (D014).
    case notRecorded

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unreadable: "Maru can’t open your records right now. If your iPhone restarted, unlock it first, then ask again."
        case .notRecorded: "Nothing was recorded. Open Maru to record your doses."
        }
    }
}

/// The snippet of "What do I take next": the part of the day, its time, and each open dose with its amount.
private struct NextDoseSnippet: View {
    let next: SiriNextDoses?
    let message: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next {
                HStack(spacing: 6) {
                    Text(next.part.title).foregroundStyle(AppGroup.appColor.tint)
                    Text(next.time.formatted(.rowTime(in: next.timeZone))).foregroundStyle(.secondary)
                }
                .font(.headline)
                ForEach(next.doses.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(next.doses[index].name).font(.body.weight(.semibold))
                        if let amount = next.doses[index].amount {
                            Text(amount).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if let message {
                Text(message).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
