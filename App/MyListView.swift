import MaruCore
import SwiftUI

/// My Items: the active items as a grid of tiles, so the user sees at once which items they have (spec 3 P02, D032).
/// A tile shows the form icon in the item color and the name. A tap opens the item detail, where the plan is.
/// The "Archived" row under the grid shows the archived items.
///
/// The tile is a kept custom control (D026): the system has no grid of cards. It uses the card color, the
/// corner shape, and the margins of an inset grouped list cell.
struct MyListView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The page of the second column at a regular width (D070). A tap on a tile or on "Archived" sets it.
    @State private var chosen: Shown?

    /// What the second column shows.
    private enum Shown: Hashable {
        case item(ItemID)
        case archived
    }

    var body: some View {
        // At a regular width, the grid is the first column, and the detail of one item stays beside it (D070).
        // An empty page has nothing to show beside it, so it keeps the full width.
        if sizeClass == .regular, let shown {
            WideColumns {
                NavigationStack { page(shown: shown) }
            } trailing: {
                NavigationStack {
                    switch shown {
                    case let .item(id): ItemDetailView(itemID: id).id(id)
                    case .archived: ArchivedListView()
                    }
                }
            }
        } else {
            NavigationStack { page(shown: nil) }
        }
    }

    /// The page of the second column: the choice of the user while it exists, else the first item.
    private var shown: Shown? {
        guard case let .loaded(snapshot) = model.content else { return nil }
        switch chosen {
        case .archived where !snapshot.archived.isEmpty: return .archived
        case let .item(id) where snapshot.list.contains { $0.id == id }: return chosen
        default: break
        }
        if let first = ordered(snapshot.list, by: model.listTimes ?? [:]).first { return .item(first.id) }
        return snapshot.archived.isEmpty ? nil : .archived
    }

    /// The My Items page. `shown` is the page of the second column, or `nil` when a tap opens a page as a push.
    private func page(shown: Shown?) -> some View {
        Group {
            if case let .loaded(snapshot) = model.content {
                ScrollView {
                    VStack(spacing: Tile.spacing) {
                        // A save with notifications off shows no alert, so the page says it in place (D028).
                        if model.settings.permission == .denied {
                            Button { model.openSettings() } label: {
                                NotificationsOffLabel()
                                    .modifier(PlainRow())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(Text("Opens settings"))
                        }
                        // The order needs the plans. The page reads them when it shows.
                        if let times = model.listTimes {
                            ItemGrid(
                                entries: ordered(snapshot.list, by: times),
                                columns: typeSize.isAccessibilitySize ? 1 : 2,
                                selection: shown.map { shown in
                                    { id in (shown == .item(id), { chosen = .item(id) }) }
                                }
                            )
                        }
                        if !snapshot.archived.isEmpty {
                            if shown != nil {
                                Button { chosen = .archived } label: { archivedRow }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(shown == .archived ? .isSelected : [])
                            } else {
                                NavigationLink { ArchivedListView() } label: { archivedRow }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, Tile.margin)
                    .padding(.vertical, 8)
                    // A tile or a row that comes or goes moves the page (D030). The first tiles show with no entrance.
                    .motion(.layout, value: layout(snapshot))
                }
                .navigationDestination(for: ItemID.self) { ItemDetailView(itemID: $0) }
                .overlay {
                    if snapshot.list.isEmpty && snapshot.archived.isEmpty {
                        ContentUnavailableView {
                            Label("No Items Yet", systemImage: "pills")
                        } actions: {
                            Button("Add Item") { model.openEditor(for: nil) }
                        }
                    }
                }
                // A save or a change gives a new snapshot, and the plans can differ.
                .task(id: snapshot) { await model.loadListTimes() }
            }
        }
        // The gray page with white cards, also while the first read runs (D028).
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .readableColumn()
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        #if DEBUG
        .modifier(DebugDataBanner())
        #endif
        .navigationTitle("My Items")
        .toolbar {
            SettingsButton()
            AddItemButton()
        }
    }

    private var archivedRow: some View {
        HStack {
            Text("Archived")
                .foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .modifier(PlainRow())
    }

    /// What gives the page its layout: the tiles in their order, and the two rows.
    private func layout(_ snapshot: Snapshot) -> [AnyHashable] {
        guard let times = model.listTimes else { return [] }
        return [model.settings.permission == .denied, snapshot.archived.isEmpty]
            + ordered(snapshot.list, by: times).map { AnyHashable($0.id) }
    }

    /// By the first time of day of the plan, then by name. An as-needed item has no time and comes last (D032).
    private func ordered(_ entries: [ListEntry], by times: [ItemID: WallClockTime]) -> [ListEntry] {
        entries.sorted { first, second in
            switch (times[first.id], times[second.id]) {
            case let (a?, b?) where a != b: a < b
            case (_?, nil): true
            case (nil, _?): false
            default: first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
        }
    }
}

extension AppModel {
    /// Reads the first time of day of each item with an active plan. The read runs when My Items shows, not
    /// at launch, so the startup path does not load the schedules (spec 9). A failed read keeps the last order.
    func loadListTimes() async {
        let now = Date()
        guard let schedules = try? await store.tapInputs().schedules else {
            if listTimes == nil { listTimes = [:] }
            return
        }
        let today = LocalDate(now, in: NamedTimeZone(device: .current, at: now) ?? .utc)
        var times: [ItemID: WallClockTime] = [:]
        for schedule in schedules where schedule.isActive(on: today) {
            guard let first = schedule.version(on: today)?.slotTimes.map(\.time).min() else { continue }
            times[schedule.itemID] = min(times[schedule.itemID] ?? first, first)
        }
        listTimes = times
    }
}

/// The measures of an inset grouped list cell, so a tile, and the graph of History, look like a card of Today.
/// The margin is also the padding inside a card.
enum Tile {
    static let margin: CGFloat = 16
    static let spacing: CGFloat = 12
    static var shape: RoundedRectangle {
        // The list cells of iOS 26 and later have a larger corner.
        if #available(iOS 26, *) { return RoundedRectangle(cornerRadius: 26, style: .continuous) }
        return RoundedRectangle(cornerRadius: 10, style: .continuous)
    }
}

/// A row with the look of one inset grouped list cell.
private struct PlainRow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Tile.margin)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: Tile.shape)
            .contentShape(Tile.shape)
    }
}

/// The tiles in rows. The tiles of one row have the same height, and a long name makes its row taller.
private struct ItemGrid: View {
    let entries: [ListEntry]
    let columns: Int
    /// At a regular width: whether the second column shows the item, and the tap that shows it (D070).
    /// `nil` when a tap opens the detail as a push.
    let selection: ((ItemID) -> (isSelected: Bool, select: () -> Void))?

    var body: some View {
        LazyVStack(spacing: Tile.spacing) {
            ForEach(Array(stride(from: 0, to: entries.count, by: columns)), id: \.self) { start in
                HStack(alignment: .top, spacing: Tile.spacing) {
                    ForEach(entries[start..<min(start + columns, entries.count)]) { ItemTile(entry: $0, selection: selection?($0.id)) }
                    // The last row keeps the column width.
                    if start + columns > entries.count {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One item: the form icon, large, in the item color, and the name. No other text (D032).
private struct ItemTile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dynamicTypeSize) private var typeSize
    let entry: ListEntry
    let selection: (isSelected: Bool, select: () -> Void)?
    @ScaledMetric(relativeTo: .headline) private var iconSize = 44

    var body: some View {
        Group {
            if let selection {
                Button(action: selection.select) { label }
                    // The tile of the item beside the grid has a ring in the tint.
                    .overlay {
                        if selection.isSelected { Tile.shape.strokeBorder(.tint, lineWidth: 2) }
                    }
                    .accessibilityAddTraits(selection.isSelected ? .isSelected : [])
            } else {
                NavigationLink(value: entry.id) { label }
            }
        }
        .buttonStyle(.pressScale)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { model.openEditor(for: entry.id) }
            Button("Archive…", systemImage: "archivebox") {
                model.askToEnd(.archive, itemID: entry.id, name: entry.name)
            }
        }
        .accessibilityValue(entry.remindersOff ? Text("Reminders off") : Text(verbatim: ""))
        .accessibilityHint(Text("Opens the details"))
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 12) {
            ItemPhotoView(reference: entry.imageReference, side: min(iconSize, 64)) {
                entry.form.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(iconSize, 64), height: min(iconSize, 64))
                    .foregroundStyle(entry.color.color)
            }
            .accessibilityHidden(true)
            // With two columns the tile has room for two lines, so most rows have one height.
            // A longer name wraps and makes the tile taller (spec 5.3).
            ZStack(alignment: .topLeading) {
                if !typeSize.isAccessibilitySize {
                    Text(verbatim: " \n ").hidden().accessibilityHidden(true)
                }
                Text(verbatim: entry.name)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline)
        }
        .padding(Tile.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: Tile.shape)
        .contentShape(.contextMenuPreview, Tile.shape)
    }
}
