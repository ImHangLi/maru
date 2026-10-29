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
                        // The person menu shows the doses of one member (D121). The rows of the other members leave the list.
                        let member = model.shownMember?.id
                        TodayContent(
                            today: today.only(member),
                            member: member,
                            hasItems: snapshot.list.contains { member == nil || $0.personID == member }
                        )
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
            // One member: the title is the name, as Health titles the data of a person who shares with you (D121).
            .navigationTitle(model.shownMember.map { Text(verbatim: $0.displayName) } ?? Text("Today"))
            .toolbar {
                SettingsButton()
                // History has its own button in the bar (spec 3 P01, D026).
                ToolbarItem(placement: .primaryAction) {
                    Button("History", systemImage: "calendar") { model.openHistory() }
                }
                AddItemButton()
                PersonMenu()
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
    /// The member that the person menu shows, or `nil` for everyone (D121).
    let member: PersonID?
    /// Whether My Items has any item. The empty text then says what to do next.
    let hasItems: Bool

    var body: some View {
        // An unconfirmed dose keeps the look of its first read, so the filter reads the current owner of the item (D121).
        let asNeededRows = model.shownRows(of: today.asNeeded).filter { member == nil || model.owner(of: $0.itemID, or: $0.look.personID) == member }
        ScrollViewReader { scroller in
            List {
                // Before iOS 26 the bar has no subtitle, so the line under the title is the first header.
                if #unavailable(iOS 26) {
                    Section {} header: { subtitle }
                }
                // One retry sends the unconfirmed events of every member, so it shows only in "Everyone". In the view of one
                // member, each row of that member keeps its own retry (D014, D121).
                if member == nil {
                    UnsavedSection()
                }
                NotificationsOffSection()
                ForEach(today.groups) { group in
                    SlotSection(group: group, timeZone: timeZone)
                        .id(group.part)
                }
                if !asNeededRows.isEmpty {
                    AsNeededSection(rows: asNeededRows, timeZone: timeZone)
                }
                // Last, under every dose (D107).
                if model.showsProCard(today) {
                    ProCardSection(date: today.date)
                }
            }
            .listStyle(.insetGrouped)
            .headerProminence(.increased)
            .headerWash()
            // The empty text is in the middle of the page (D026).
            .overlay {
                if today.groups.isEmpty && asNeededRows.isEmpty {
                    if hasItems {
                        ContentUnavailableView("Nothing to take today. Enjoy it.", systemImage: "checkmark.circle")
                    } else {
                        ContentUnavailableView {
                            Label("Let’s add the first thing you take.", systemImage: "pills")
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
        .modifier(Subtitle(text: subtitle))
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
        var layout: [AnyHashable] = [model.unsavedCount > 0, model.settings.permission == .denied, model.showsProCard(today)]
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

    /// The date, or a short line in its place when every planned dose of today has a record (D101).
    private var subtitle: Text {
        if model.isComplete(today) {
            Text("All done for today. Nice work.")
        } else {
            Text(today.generatedAt, format: dateFormat)
        }
    }

    /// The date in the language and the region of the user, for example "Sunday, October 11" (spec 13.2).
    private var dateFormat: Date.FormatStyle {
        var format = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        format.timeZone = timeZone
        return format
    }

}

/// The line under the title, in the system navigation bar (iOS 26 and later).
private struct Subtitle: ViewModifier {
    let text: Text

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.navigationSubtitle(text)
        } else {
            content
        }
    }
}
