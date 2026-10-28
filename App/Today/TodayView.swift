import MaruCore
import SwiftUI
import UIKit

/// The Today page: one section per part of the day in a system grouped list (spec 3 P01, docs/design.md, D026).
struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.today.path) {
            Group {
                // While the first read runs, the page is empty like the launch screen (spec 9).
                if case let .loaded(snapshot) = model.content {
                    if let today = snapshot.today {
                        TodayContent(today: today, hasItems: !snapshot.list.isEmpty)
                            .onAppear { model.todayContentDidAppear() }
                    } else {
                        ContentUnavailableView {
                            Label("Maru Can’t Use Your Time Zone", systemImage: "globe")
                        } description: {
                            Text("In iPhone Settings, choose a city for your time zone.")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            #if DEBUG
            .modifier(DebugDataBanner())
            .modifier(DebugNoticeAlert())
            #endif
            .navigationTitle("Today")
            .toolbar {
                SettingsButton()
                // History has its own button in the bar (spec 3 P01, D026).
                ToolbarItem(placement: .primaryAction) {
                    Button("History", systemImage: "calendar") { model.openHistory() }
                }
                AddItemButton()
            }
            .navigationDestination(isPresented: $model.history.isOpen) { HistoryView() }
            .navigationDestination(for: ItemID.self) { ItemDetailView(itemID: $0) }
        }
        // A clock change, a new time zone, or a midnight in the device zone.
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            model.timeDidChange()
        }
    }
}

private struct TodayContent: View {
    @Environment(AppModel.self) private var model
    let today: TodaySnapshot
    /// Whether My Items has any item. The empty text then says what to do next.
    let hasItems: Bool

    var body: some View {
        let asNeededRows = model.shownRows(of: today.asNeeded)
        ScrollViewReader { scroller in
            List {
                // Before iOS 26 the bar has no subtitle, so the date is the first header.
                if #unavailable(iOS 26) {
                    Section {} header: {
                        Text(today.generatedAt, format: dateFormat)
                    }
                }
                UnsavedSection()
                NotificationsOffSection()
                ForEach(today.groups) { group in
                    SlotSection(group: group, timeZone: timeZone)
                        .id(group.part)
                }
                if !asNeededRows.isEmpty {
                    AsNeededSection(rows: asNeededRows, timeZone: timeZone)
                }
            }
            .listStyle(.insetGrouped)
            .headerProminence(.increased)
            .headerWash()
            // The empty text is in the middle of the page (D026).
            .overlay {
                if today.groups.isEmpty && asNeededRows.isEmpty {
                    if hasItems {
                        ContentUnavailableView("Nothing Planned Today", systemImage: "checkmark.circle")
                    } else {
                        ContentUnavailableView {
                            Label("No Items Yet", systemImage: "pills")
                        } description: {
                            Text("Tap + to add a supplement or medication.")
                        }
                    }
                }
            }
            // A row or a section that comes or goes moves the list, and the empty text fades (D030).
            .motion(.layout, value: layout(asNeededRows))
            // A tapped reminder scrolls to its section (spec 8.3).
            .onChange(of: model.today.focus, initial: true) { _, focus in
                guard let focus, let part = today.groups.first(where: {
                    $0.entries.contains { focus.keys.contains($0.occurrence.key) }
                })?.part else { return }
                Task { @MainActor in
                    withMotion(.layout) { scroller.scrollTo(part, anchor: .top) }
                }
            }
        }
        .modifier(DateSubtitle(date: today.generatedAt, format: dateFormat))
        // The haptic follows the commit, not the tap (spec 7.2).
        .sensoryFeedback(.success, trigger: model.today.commitCount)
        .alert(
            model.today.failure?.kind.alertTitle(changed: "Today Changed") ?? Text("Not Saved"),
            isPresented: Binding(get: { model.today.failure != nil }, set: { if !$0 { model.today.failure = nil } }),
            presenting: model.today.failure
        ) { failure in
            if case .notSaved = failure.kind {
                Button("Try Again") { model.retry(failure) }
                Button("Cancel", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { failure in
            failure.kind.alertMessage
        }
    }

    private var timeZone: TimeZone {
        TimeZone(identifier: today.timeZone.identifier) ?? .current
    }

    /// What gives the list its layout: the sections, the rows, and the lines of each row. A record is not
    /// in it, because a recorded row keeps its place (spec 4).
    private func layout(_ asNeededRows: [AsNeededCard.Row]) -> [AnyHashable] {
        var layout: [AnyHashable] = [model.unsavedCount > 0, model.settings.permission == .denied]
        for group in today.groups {
            layout.append(group.part)
            for entry in group.entries {
                layout.append(entry.id)
                layout.append(entry.look.remindersOff)
            }
        }
        for row in asNeededRows {
            layout.append(row.itemID)
            for dose in row.doses { layout.append(dose.id) }
        }
        return layout
    }

    /// The date in the language and the region of the user, for example "Sunday, October 11" (spec 13.2).
    private var dateFormat: Date.FormatStyle {
        var format = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        format.timeZone = timeZone
        return format
    }

}

/// The date under the title, in the system navigation bar (iOS 26 and later).
private struct DateSubtitle: ViewModifier {
    let date: Date
    let format: Date.FormatStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle(Text(date, format: format))
        } else {
            content
        }
    }
}
