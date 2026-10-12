import MaruCore
import SwiftUI

/// The history page: the graph, and under it one row for each item of the last 7 days (spec 3 P05, D054).
/// A row opens the log of the item, and a tap on a day of the graph opens the log of the day. Both logs are
/// timelines of every action (D032). Today opens the page from the History button in the bar.
/// It has no streak and no bulk fill (D021).
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var isTop = true

    var body: some View {
        Group {
            // The first days show complete, with no entrance (D030). They wait for the first read of the
            // graph too, so the graph does not push them down.
            if model.history.days != nil, model.history.graphDidLoad {
                HistoryList()
            } else {
                // A retry of the banner can show its error also before the first read ends.
                List { UnsavedSection() }
                    .listStyle(.insetGrouped)
                    .overlay {
                        if model.history.loadFailure != nil {
                            ContentUnavailableView {
                                Text("Can’t Show History")
                            } description: {
                                Text("Unlock your iPhone, then try again.")
                            } actions: {
                                Button("Try Again") { model.loadHistory() }
                            }
                        }
                    }
            }
        }
        #if DEBUG
        .modifier(DebugDataBanner())
        #endif
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        // A log that opens over the page shows the haptic and the alerts itself, so they never come twice.
        .onAppear { isTop = true }
        .onDisappear { isTop = false }
        .modifier(HistoryCorrectionFeedback(isActive: isTop))
    }
}

/// The haptic and the alerts of a correction (D014, spec 7.2). The page and each log use it, and only the one
/// on top is active, so an alert never comes twice.
struct HistoryCorrectionFeedback: ViewModifier {
    @Environment(AppModel.self) private var model
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            // The haptic follows the commit, not the tap (spec 7.2).
            .sensoryFeedback(.success, trigger: model.today.commitCount) { _, _ in isActive }
            // On the page, not on the list, so a retry of the banner can show its error also on an empty page.
            .alert(
                failureTitle,
                isPresented: Binding(
                    get: { isActive && model.history.failure != nil },
                    set: { if !$0 { model.history.failure = nil } }
                ),
                presenting: model.history.failure
            ) { failure in
                if case .notSaved = failure.kind {
                    Button("Try Again") { model.retryHistory(failure) }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("OK", role: .cancel) {}
                }
            } message: { failure in
                failureMessage(failure.kind)
            }
            .background {
                // A second alert needs its own view. An as-needed correction sends its own pair again (D014).
                Color.clear.alert(
                    asNeededFailureTitle,
                    isPresented: Binding(
                        get: { isActive && model.history.asNeededFailure != nil },
                        set: { if !$0 { model.history.asNeededFailure = nil } }
                    ),
                    presenting: model.history.asNeededFailure
                ) { failure in
                    if case .notSaved = failure.kind {
                        Button("Try Again") { model.retry(failure) }
                        Button("Cancel", role: .cancel) {}
                    } else {
                        Button("OK", role: .cancel) {}
                    }
                } message: { failure in
                    switch failure.kind {
                    case let .notSaved(error): failureMessage(.notSaved(error))
                    case .changed: failureMessage(.changed)
                    }
                }
            }
    }

    private var failureTitle: Text {
        if case .changed = model.history.failure?.kind { Text("History changed") } else { Text("Not saved") }
    }

    private var asNeededFailureTitle: Text {
        if case .changed = model.history.asNeededFailure?.kind { Text("History changed") } else { Text("Not saved") }
    }

    private func failureMessage(_ kind: TodayFailure.Kind) -> Text {
        switch kind {
        case .notSaved(.unavailable):
            Text("Unlock your iPhone, then try again.")
        case .notSaved(.diskFull):
            Text("Your iPhone is full. Free some storage, then try again.")
        case .notSaved:
            Text("Maru couldn’t save this. Try again.")
        case .changed:
            Text("This item changed. Check it, then try again.")
        }
    }
}

private struct HistoryList: View {
    @Environment(AppModel.self) private var model
    /// The day that the graph selected (D041). It stays while the log of the day shows.
    @State private var selection: LocalDate?
    /// The day whose log shows (D054).
    @State private var presentedDay: LocalDate?

    var body: some View {
        let weeks = model.historyWeeks()
        List {
            UnsavedSection()
            if !weeks.isEmpty || model.history.graph != nil {
                Section {
                    if weeks.isEmpty {
                        Text("Nothing planned or recorded.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(weeks, id: \.itemID) { HistoryItemRow(week: $0) }
                } header: {
                    Text("Last 7 Days")
                }
            }
            // A failed read keeps the days of the last read. The error stays until a read succeeds.
            if let failure = model.history.loadFailure {
                Section {
                    Button("Try Again") { model.loadHistory() }
                } header: {
                    Text("Can’t Show History")
                } footer: {
                    if failure == .unavailable {
                        Text("Unlock your iPhone, then try again.")
                    } else {
                        Text("Maru couldn’t read the history. Try again.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // A row that comes or goes moves the list (D030).
        .motion(.layout, value: weeks.map(\.itemID))
        .safeAreaInset(edge: .top, spacing: 0) {
            if let graph = model.history.graph {
                HistoryGraphView(graph: graph, counts: model.history.graphCounts, selection: $selection) {
                    presentedDay = selection
                }
                .padding(.horizontal, Tile.margin)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            }
        }
        // A day of the graph opens its log. The selection clears when the log closes.
        .navigationDestination(item: $presentedDay) { HistoryLogView(scope: .day($0)) }
        .onChange(of: presentedDay) { _, day in
            if day == nil { selection = nil }
        }
        .overlay {
            if weeks.isEmpty, model.history.graph == nil, model.history.loadFailure == nil {
                ContentUnavailableView {
                    Text("No History Yet")
                } description: {
                    Text("What you record shows here.")
                }
            }
        }
    }
}

extension LocalDate {
    /// Noon of the date in UTC, for a date format with the UTC time zone. The date never moves to another day.
    var noon: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .utc
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .now
    }
}

extension Date.FormatStyle {
    func timeZone(_ zone: TimeZone) -> Date.FormatStyle {
        var style = self
        style.timeZone = zone
        return style
    }
}

extension TimeZone {
    static let utc = TimeZone(identifier: "UTC")!
}
