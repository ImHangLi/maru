import AppIntents
import Foundation
import MaruCore
import MaruDatabase
import WidgetKit

/// One state of a widget at a time.
struct DayEntry: TimelineEntry {
    enum Content {
        case day(WidgetDay)
        /// The database is locked, not there yet, or not readable. The widget asks to open Maru.
        case unavailable
    }

    let date: Date
    let content: Content
    let tint: ItemColor
}

/// The two widgets have no setting. The configuration intent only gives the async provider API.
struct NoConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Maru"

    init() {}
}

/// Reads today from the database in the App Group (D048). It writes only what the app writes at a launch:
/// the occurrences of the day. The widget never records here.
struct DayProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), content: .day(.sample), tint: AppGroup.appColor)
    }

    func snapshot(for configuration: NoConfiguration, in context: Context) async -> DayEntry {
        if context.isPreview { return placeholder(in: context) }
        return await Self.entries(at: Date()).first!
    }

    func timeline(for configuration: NoConfiguration, in context: Context) async -> Timeline<DayEntry> {
        let now = Date()
        let entries = await Self.entries(at: now)
        guard case let .day(day) = entries[0].content else {
            // A locked iPhone, or a database that is not there. Try again soon. A tap or a launch also reloads.
            return Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60)))
        }
        return Timeline(entries: entries, policy: .after(day.expiresAt))
    }

    /// One entry for now, and one at each change of the part of the day, so the current slot moves with no reload.
    private static func entries(at now: Date) async -> [DayEntry] {
        let tint = AppGroup.appColor
        guard let day = await load(at: now) else { return [DayEntry(date: now, content: .unavailable, tint: tint)] }
        let dates = [now] + day.partChanges(after: now)
        return dates.map { DayEntry(date: $0, content: .day(day), tint: tint) }
    }

    private static func load(at now: Date) async -> WidgetDay? {
        guard let directory = AppGroup.databaseDirectory,
              let timeZone = NamedTimeZone(device: .current, at: now),
              // The app moves the database into the container at its first launch. Before that, the widget must
              // not create an empty one, because the app would then not move the real data (D048).
              (try? LocalStore.hasDatabase(at: directory)) == true,
              let store = try? LocalStore(directory: directory),
              let items = try? await store.items(),
              let loaded = try? await TodaySnapshot.load(
                  from: store, items: items, remindersOff: [], at: now, deviceTimeZone: timeZone, generation: 0
              )
        else { return nil }
        return WidgetDay(loaded.snapshot, occurrences: loaded.occurrences, at: now)
    }
}
