import Foundation

/// Where the engine keeps the device time zone of its runs: `UserDefaults.standard`, under a key that only this type uses.
/// It must keep it after the app stops, because a tap can start the app.
///
/// A zone identifier and a run time hold no item name, no dose, and no intake time (spec 10).
/// A tap can start the app before the database opens, so the record stays outside the database.
/// The zone and its time are one value under one key, so a read never mixes a new zone with an old time.
public struct DefaultsTimeZoneRecord: Sendable {
    static let key = "reminders.observedTimeZone.v2"

    public init() {}

    public func load() -> ObservedTimeZone? {
        guard let value = UserDefaults.standard.dictionary(forKey: Self.key),
              let identifier = value["zone"] as? String,
              let zone = try? NamedTimeZone(identifier: identifier),
              let since = value["since"] as? Date
        else { return nil }
        return ObservedTimeZone(timeZone: zone, since: since)
    }

    public func save(_ observed: ObservedTimeZone) {
        UserDefaults.standard.set(["zone": observed.timeZone.identifier, "since": observed.since], forKey: Self.key)
    }

    /// Records the zone of a successful run. The time changes only when the zone changes, so a run that
    /// a tap starts does not hide that the zone stayed the same since before the delivery.
    func observe(_ timeZone: NamedTimeZone, at now: Date) {
        guard load()?.timeZone != timeZone else { return }
        save(ObservedTimeZone(timeZone: timeZone, since: now))
    }
}
