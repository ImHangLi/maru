import MaruCore
import SwiftUI

/// A log under the history page (D054): the timeline of every action, with all corrections.
/// The log of an item lists its days, newest first, and older days load when the list ends.
/// The log of a day lists the actions of that day. Undone and replaced actions stay in both (D032).
struct HistoryLogView: View {
    enum Scope: Hashable {
        case item(ItemID)
        case day(LocalDate)
    }

    @Environment(AppModel.self) private var model
    let scope: Scope

    var body: some View {
        let shown = sections
        List {
            // One retry sends the events of every member, so a log of the History of one member does not show it (D129).
            if model.history.owner == nil {
                UnsavedSection()
            }
            ForEach(shown, id: \.date) { section in
                Section {
                    ForEach(section.entries) { HistoryEntryRow(entry: $0) }
                } header: {
                    // The log of a day has the date in its title.
                    if case .item = scope { Text(model.historyTitle(of: section.date)) }
                }
            }
            if let failure = model.history.loadFailure {
                Section {
                    Button("Try Again") { model.loadHistory() }
                } header: {
                    Text("Can’t Show History")
                } footer: {
                    if failure == .unavailable {
                        Text("Unlock your iPhone, then try again.")
                    } else {
                        Text("Maru couldn’t read the history.")
                    }
                }
            } else if isLoading {
                // The end of the list loads one more page of days. Each loaded page gives the row a new
                // identity, so a row that is still on the display loads the next page.
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .id(model.history.loadedDayCount)
                        .onAppear(perform: loadMore)
                }
            }
        }
        .listStyle(.insetGrouped)
        // A row that comes or goes moves the list (D030).
        .motion(.layout, value: shown.flatMap { $0.entries.map(\.id) })
        .overlay {
            if shown.isEmpty, !isLoading, model.history.loadFailure == nil {
                ContentUnavailableView {
                    Label("No Doses", systemImage: "pills")
                } description: {
                    Text("Nothing planned or recorded.")
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(HistoryCorrectionFeedback(isActive: true))
    }

    private var title: Text {
        switch scope {
        case let .item(id): Text(verbatim: model.history.looks[id]?.name ?? "")
        case let .day(date): Text(verbatim: date.shortLabel)
        }
    }

    /// A day with only open doses of today has no row, so it has no section.
    private var sections: [(date: LocalDate, entries: [HistoryEntry])] {
        switch scope {
        case let .item(id):
            return model.historyLogDays(of: id)
                .map { (date: $0.date, entries: model.entries(of: $0)) }
                .filter { !$0.entries.isEmpty }
        case let .day(date):
            guard let day = model.historyLogDays(of: nil).first(where: { $0.date == date }) else { return [] }
            let entries = model.entries(of: day)
            return entries.isEmpty ? [] : [(date: date, entries: entries)]
        }
    }

    /// An older page is still to load: for an item, any page. For a day, the page of that day.
    private var isLoading: Bool {
        guard model.history.hasEarlier || model.history.days == nil else { return false }
        switch scope {
        case .item: return true
        case let .day(date):
            guard let today = model.history.today else { return true }
            return today.days(since: date) >= model.history.loadedDayCount
        }
    }

    private func loadMore() {
        switch scope {
        case .item: model.showEarlierHistory()
        case let .day(date): model.showHistory(through: date)
        }
    }
}

/// The full log of one item from the item detail (D091). It reads the history for its own use when the History page is
/// not open, and it lets the read go when it closes. The list loads older days until the first day of the item, so a day
/// older than the graph and a day of an archived item are in reach.
struct ItemLogView: View {
    @Environment(AppModel.self) private var model
    let itemID: ItemID

    var body: some View {
        HistoryLogView(scope: .item(itemID))
            .onAppear { model.openItemLog(of: itemID) }
            .onDisappear { model.closeItemLog() }
    }
}
