import AppIntents
import MaruCore
import MaruDatabase
import SwiftUI

// Siri and Shortcuts (D108). Each intent runs in the app process, in the background, and calls an operation of the one
// model (spec 6). The two questions only read. "Record my doses" records with the record transaction after a confirmation,
// and it says "recorded" only after the commit (spec 7.2). Analytics gets only the `used_siri` flag of the day (D127). With "Show Names in Reminders" off,
// Siri says the number of doses in place of the names (D029, D108).

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
            return try await AppModel.shared.siriItems().map {
                ItemEntity(id: $0.id.rawValue, name: $0.owner?.label($0.name) ?? $0.name)
            }
        } catch {
            throw SiriProblem.unreadable
        }
    }
}

/// An active member of the Family, so "Record my doses" can ask for whom (D129). It holds the ID and the name, and nothing else.
struct MemberEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Person or Pet"
    static let defaultQuery = MemberEntityQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// The active members of the store. An archived member is not offered.
struct MemberEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [MemberEntity] {
        try await Self.members().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MemberEntity] {
        try await Self.members()
    }

    @MainActor
    private static func members() async throws -> [MemberEntity] {
        do {
            return try await AppModel.shared.store.people().filter { !$0.isArchived }.map {
                MemberEntity(id: $0.id.rawValue, name: $0.displayName)
            }
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
            let showsNames = AppModel.shared.showsNamesInReminders
            let names = showsNames ? doses.doses.map(\.name).formatted(.list(type: .and)) : SiriText.count(doses.doses.count)
            let time = doses.time.formatted(.rowTime(in: doses.timeZone))
            return .result(
                dialog: "Next up: \(names), planned for \(time).",
                view: NextDoseSnippet(next: doses, showsNames: showsNames, message: nil)
            )
        case .allDone:
            let message: LocalizedStringResource = "All done for today. Nice work."
            return .result(dialog: IntentDialog(message), view: NextDoseSnippet(next: nil, showsNames: false, message: message))
        case .nothingPlanned:
            let message: LocalizedStringResource = "Nothing to take today. Enjoy it."
            return .result(dialog: IntentDialog(message), view: NextDoseSnippet(next: nil, showsNames: false, message: message))
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
        // The user said the name. With names off, Siri does not say it again.
        let showsNames = AppModel.shared.showsNamesInReminders
        guard let last else {
            if showsNames { return .result(dialog: "Maru has no taken record for \(item.name) yet.") }
            return .result(dialog: "Maru has no taken record for this item yet.")
        }
        let name = last.owner?.label(last.name) ?? last.name
        let time = last.takenAt.formatted(date: .omitted, time: .shortened)
        let calendar = Calendar.current
        if calendar.isDateInToday(last.takenAt) {
            if showsNames { return .result(dialog: "Your last record for \(name): taken today at \(time).") }
            return .result(dialog: "Your last record: taken today at \(time).")
        }
        if calendar.isDateInYesterday(last.takenAt) {
            if showsNames { return .result(dialog: "Your last record for \(name): taken yesterday at \(time).") }
            return .result(dialog: "Your last record: taken yesterday at \(time).")
        }
        let date = last.takenAt.formatted(date: .abbreviated, time: .omitted)
        if showsNames { return .result(dialog: "Your last record for \(name): taken on \(date) at \(time).") }
        return .result(dialog: "Your last record: taken on \(date) at \(time).")
    }
}

/// "Record my doses": records the open doses of the part of the day of the clock as taken now, after a confirmation.
/// A locked iPhone asks for an unlock first, as the "Taken" action of a reminder does (D034, D066).
///
/// With two or more active members, Siri asks "For whom?" and records only the doses of that member, so one confirmation never
/// records for another member (D123, D129). With names off, Siri speaks no member name and no item name (T62).
struct RecordDueDosesIntent: AppIntent {
    static let title: LocalizedStringResource = "Record Due Doses"
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "For", requestValueDialog: "For whom?")
    var member: MemberEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = AppModel.shared
        let due: SiriDueDoses
        do {
            due = try await model.siriDueDoses(for: member.map { PersonID($0.id) })
        } catch SiriDueDosesError.severalMembers {
            // The list of members shows on the unlocked iPhone. The choice then reads the doses again.
            throw $member.needsValueError("For whom?")
        } catch {
            throw SiriProblem.unreadable
        }
        guard !due.entries.isEmpty else {
            return .result(dialog: "Nothing is due right now. You’re all set.")
        }
        guard model.showsNamesInReminders else {
            let count = SiriText.count(due.entries.count)
            // A "Cancel" throws, and nothing is recorded.
            try await requestConfirmation(result: .result(dialog: "Record as taken now: \(count)?"))
            guard await model.recordFromSiri(due) else { throw SiriProblem.notConfirmed }
            return .result(dialog: "Recorded as taken: \(count).")
        }
        if let member, due.namesMember {
            let names = due.entries.map(\.look.name).formatted(.list(type: .and))
            try await requestConfirmation(result: .result(dialog: "Record as taken now for \(member.name): \(names)?"))
            guard await model.recordFromSiri(due) else { throw SiriProblem.notConfirmed }
            return .result(dialog: "Recorded as taken for \(member.name): \(names).")
        }
        let names = due.names.formatted(.list(type: .and))
        try await requestConfirmation(result: .result(dialog: "Record as taken now: \(names)?"))
        guard await model.recordFromSiri(due) else { throw SiriProblem.notConfirmed }
        return .result(dialog: "Recorded as taken: \(names).")
    }
}

/// The words that Siri says in place of the names when "Show Names in Reminders" is off (D029, D108).
private enum SiriText {
    /// For example "2 doses".
    static func count(_ count: Int) -> String {
        String(localized: "\(count) doses", comment: "Siri: the number of doses in place of the names when \"Show Names in Reminders\" is off (D108).")
    }
}

/// What Siri says when Maru can not read or record. The text names no item.
enum SiriProblem: Error, CustomLocalizedStringResourceConvertible {
    /// The database did not open or a read failed. After a restart and before the first unlock, file protection is the
    /// usual cause (D066).
    case unreadable
    /// The record transaction gave no commit. SQLite can commit before the flush fails, so the dose can be stored.
    /// After a storage failure, the same event waits on Today for a retry (D014).
    case notConfirmed
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .unreadable: "Maru can’t open your records right now. If your iPhone restarted, unlock it first, then ask again."
        case .notConfirmed: "Maru couldn’t confirm the save. Open Maru to check your records."
        }
    }
}

/// The snippet of "What do I take next": the part of the day, its time, and each open dose with its amount.
/// With names off, it shows the number of doses and no name or amount.
private struct NextDoseSnippet: View {
    let next: SiriNextDoses?
    let showsNames: Bool
    let message: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next {
                HStack(spacing: 6) {
                    Text(next.part.title).foregroundStyle(AppGroup.appColor.tint)
                    Text(next.time.formatted(.rowTime(in: next.timeZone))).foregroundStyle(.secondary)
                }
                .font(.headline)
                if showsNames {
                    ForEach(next.doses.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 0) {
                            Text(next.doses[index].name).font(.body.weight(.semibold))
                            if let amount = next.doses[index].amount {
                                Text(amount).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text(SiriText.count(next.doses.count)).font(.body.weight(.semibold))
                }
            } else if let message {
                Text(message).font(.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
