import MaruCore
import SwiftUI

/// The history as one timeline: every action of the user, newest first, grouped by day (spec 3 P05, D032).
/// A planned dose of a past day with no record stays in its day. Older days load when the list ends.
/// Today opens it from the History button in the bar. It has no streak and no bulk fill (D021).
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            // The first days show complete, with no entrance (D030). They wait for the first read of the
            // graph too, so the graph does not push them down.
            if let days = model.history.days, model.history.graphDidLoad {
                HistoryList(days: days)
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
        // The haptic follows the commit, not the tap (spec 7.2).
        .sensoryFeedback(.success, trigger: model.today.commitCount)
        // On the page, not on the list, so a retry of the banner can show its error also on an empty page.
        .alert(
            failureTitle,
            isPresented: Binding(get: { model.history.failure != nil }, set: { if !$0 { model.history.failure = nil } }),
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
                    get: { model.history.asNeededFailure != nil },
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
    let days: [HistoryDay]
    /// The day that the graph selected (D041). Only the graph sets it.
    @State private var selection: LocalDate?
    /// The selected day that the timeline did not scroll to yet, because an older page still loads.
    @State private var scrollTarget: LocalDate?

    var body: some View {
        // A day with only open doses of today has no row, so it has no section.
        let sections = days.map { (date: $0.date, entries: model.entries(of: $0)) }.filter { !$0.entries.isEmpty }
        ScrollViewReader { scroller in
            List {
                UnsavedSection()
                ForEach(sections, id: \.date) { section in
                    Section {
                        ForEach(section.entries) { HistoryEntryRow(entry: $0, day: section.date) }
                    } header: {
                        Text(title(of: section.date))
                    }
                    .id(section.date)
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
                } else if model.history.hasEarlier {
                    // The end of the list loads one more page of days. Each loaded page gives the row a new
                    // identity, so a row that is still on the display loads the next page.
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .id(model.history.loadedDayCount)
                            .onAppear { model.showEarlierHistory() }
                    }
                }
            }
            .listStyle(.insetGrouped)
            // A row that comes or goes moves the list (D030).
            .motion(.layout, value: sections.flatMap { $0.entries.map(\.id) })
            .safeAreaInset(edge: .top, spacing: 0) {
                if let graph = model.history.graph {
                    HistoryGraphView(graph: graph, counts: model.history.graphCounts, selection: $selection) {
                        if let selection {
                            model.showHistory(through: selection)
                            scrollTarget = selection
                            scroll(to: selection, sections, scroller)
                        } else if let first = sections.first?.date {
                            // No selection: the timeline starts at today again.
                            scrollTarget = nil
                            withMotion(.layout) { scroller.scrollTo(first, anchor: .top) }
                        }
                    }
                    .padding(.horizontal, Tile.margin)
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .onChange(of: sections.map(\.date)) {
                if let scrollTarget { scroll(to: scrollTarget, sections, scroller) }
            }
            .modifier(ClearsSelectionOnScroll(selection: $selection))
            #if DEBUG
            .onAppear {
                // `-MaruHistory older`: scroll to the oldest loaded day. The simulator cannot scroll.
                guard DebugLaunch.history == "older", let last = sections.last?.date else { return }
                Task { @MainActor in scroller.scrollTo(last, anchor: .top) }
            }
            #endif
        }
        .overlay {
            if sections.isEmpty, !model.history.hasEarlier, model.history.loadFailure == nil {
                ContentUnavailableView {
                    Text("No History Yet")
                } description: {
                    Text("What you record shows here.")
                }
            }
        }
    }

    /// Scrolls the timeline to the selected day, so its section comes first under the graph. A day with no row
    /// gives the nearest older day with rows. The scroll waits while the page of that day loads.
    private func scroll(to target: LocalDate, _ sections: [(date: LocalDate, entries: [HistoryEntry])], _ scroller: ScrollViewProxy) {
        guard let today = model.history.today else { return }
        let isLoaded = today.days(since: target) < model.history.loadedDayCount || !model.history.hasEarlier
        guard isLoaded, let section = sections.first(where: { $0.date <= target }) ?? sections.last else { return }
        scrollTarget = nil
        withMotion(.layout) { scroller.scrollTo(section.date, anchor: .top) }
    }

    /// "Today", "Yesterday", then the weekday and the date, for example "Friday, October 9" (spec 13.2).
    private func title(of date: LocalDate) -> String {
        if let today = model.history.today {
            if date == today { return String(localized: "Today") }
            if date == today.adding(days: -1) { return String(localized: "Yesterday") }
        }
        return date.noon.formatted(Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day().timeZone(.utc))
    }
}

/// A scroll of the timeline by hand clears the selection of the graph (D041). iOS 17 has no scroll phase,
/// so there the selection stays until a tap on the selected day.
private struct ClearsSelectionOnScroll: ViewModifier {
    @Binding var selection: LocalDate?

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.onScrollPhaseChange { _, phase in
                if phase == .interacting { selection = nil }
            }
        } else {
            content
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
