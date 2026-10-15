import Foundation
@testable import MaruCore
@testable import MaruNotifications

/// The invariant of D084 and D086, computed from the `Truth` of the user and from nothing else:
///
/// 1. Every pending request names, for each date on which it fires, only open doses of that date and that time,
///    and at least one. An archived, deleted, or paused item, a recorded or skipped dose, and a dose of an
///    item that an alarm covers are not open doses for a notification.
/// 2. Every delivered Maru notification names exactly the open doses of its occurrence now. It belongs to today
///    or yesterday. Anything else must be gone.
/// 3. Every open dose with a time in the horizon has a pending request that fires at its time and names it.
/// 4. The alarms wait for exactly the open doses of the items that an alarm covers.
struct Oracle {
    struct Checks {
        /// Check that every open dose has a reminder in the next `coverageHours`.
        var coverage = true
        var coverageHours = 36.0
        /// Check that every follow-up that the settings ask for is pending, for the next `followUpHours`.
        var followUpCoverage = false
        var followUpHours = 12.0
        var alarms = true
        /// The alarm system refuses alarms, so the items with an alarm keep their notification.
        var alarmsFail = false
        /// A plan that has more requests than the budget of 48 or the room of 64 can leave a schedule "not set".
        var allowsOverLimit = false
    }

    let phone: Phone

    private var truth: Truth { phone.truth }
    private var device: SimDevice { phone.device }
    private var showsNames: Bool { phone.privacy.load() == .showNames }

    // MARK: Expected content

    /// An alarm covers the item, so the item has no notification at its time.
    private func isCovered(_ item: SimItem) -> Bool {
        device.alarmsAllowed && item.alarm && !phone.checks.alarmsFail
    }

    /// The open doses that a first reminder can name at `instant`.
    private func openDoses(at instant: Date, covered: Bool = false) -> [SimDose] {
        truth.doses(from: instant.addingTimeInterval(-1), through: instant, deviceZone: device.zone).filter {
            $0.instant == instant && truth.isOpen($0) && !$0.item.isPaused && isCovered($0.item) == covered
        }
    }

    /// The doses of the series of a request: the ones that its zone rule gives.
    private func rule(_ key: String, _ doses: [SimDose]) -> [SimDose] {
        let zone = device.zone
        if key == "device" {
            return doses.filter { $0.rule == .device || $0.rule == .fixed(zone) }
        }
        guard let named = try? NamedTimeZone(identifier: key) else { return [] }
        return doses.filter { $0.rule == .fixed(named) || ($0.rule == .device && zone == named) }
    }

    private func names(_ doses: [SimDose]) -> [String] {
        var seen = Set<ItemID>()
        let order = truth.items.map(\.id)
        return doses.sorted { order.firstIndex(of: $0.item.id)! < order.firstIndex(of: $1.item.id)! }
            .filter { seen.insert($0.item.id).inserted }.map(\.item.name)
    }

    private func text(_ kind: ReminderContent.Kind, _ names: [String]) -> ReminderText {
        phone.center.text(for: ReminderContent(kind: kind, names: showsNames ? names : nil))
    }

    // MARK: Identifier parts

    private struct SeriesID {
        let zone: String
        let time: WallClockTime
        let date: LocalDate?
    }

    private func series(_ identifier: String) -> SeriesID? {
        let parts = identifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == "series" else { return nil }
        return SeriesID(zone: parts[1], time: Phone.wallClock(parts[2]), date: Self.parseDate(parts[3]))
    }

    private struct FollowUpID {
        let zone: String
        let date: LocalDate
        let time: WallClockTime
        let minutes: Int
    }

    private func followUp(_ identifier: String) -> FollowUpID? {
        let parts = identifier.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5, parts[0] == "followup", let date = Self.parseDate(parts[2]) else { return nil }
        return FollowUpID(zone: parts[1], date: date, time: Phone.wallClock(parts[3]), minutes: Int(parts[4].dropFirst())!)
    }

    private static func parseDate(_ text: String) -> LocalDate? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return try? LocalDate(year: parts[0], month: parts[1], day: parts[2])
    }

    // MARK: Follow-ups

    /// The names that a follow-up at `minutes` after the dose time of `date` can name: items with "Remind Again" on,
    /// whose dose is open, and whose follow-ups reach this delay before they stop (D039, D079).
    private func followUpNames(date: LocalDate, time: WallClockTime, minutes: Int) -> [String] {
        var doses: [SimDose] = []
        for item in truth.items where !item.isArchived && !item.isPaused {
            guard let setting = item.followUp, item.isDue(on: date) else { continue }
            let zone: NamedTimeZone = switch item.zone {
            case .device: device.zone
            case let .fixed(zone): zone
            }
            for slot in item.slots where slot.time(on: date) == time {
                let key = ClosedKey(slot: slot.id, date: date)
                guard !truth.closed.contains(key) else { continue }
                let interval = setting.interval.rawValue
                guard minutes % interval == 0, minutes / interval <= setting.count.limit else { continue }
                let slotInstant = zone.resolve(time, on: date).earliestInstant
                let fire = slotInstant.addingTimeInterval(Double(minutes) * 60)
                // The follow-ups of a dose stop before the next dose of the item and before 01:00 of the next day.
                let later = truth.doses(from: slotInstant, through: slotInstant.addingTimeInterval(3 * 86_400), deviceZone: device.zone)
                    .filter { $0.item.id == item.id }.map(\.instant).min()
                let stop = min(FollowUpPlan.latestInstant(of: date, in: zone), later ?? .distantFuture)
                guard fire < stop else { continue }
                doses.append(SimDose(item: item, slot: slot.id, date: date, time: time, instant: slotInstant, zone: zone, rule: item.zone))
            }
        }
        return names(doses)
    }

    // MARK: The violations

    func violations() async -> [String] {
        var found: [String] = []
        let now = device.now
        let pending = await phone.center.pending
        let shown = await phone.center.shown
        let zone = device.zone

        // The pending requests.
        for notification in pending.values.sorted(by: { $0.identifier < $1.identifier }) {
            if let id = series(notification.identifier) {
                let fires = FakeNotificationCenter.fireDates(
                    of: notification.trigger, after: now, through: now.addingTimeInterval(8 * 86_400), deviceZone: zone
                )
                for fire in fires {
                    let all = openDoses(at: fire)
                    let ruled = rule(id.zone, all)
                    let candidates = [text(.due, names(all)), text(.due, names(ruled))]
                    let label = "pending \(notification.identifier) (\"\(notification.text.body)\") at \(Self.format(fire, zone))"
                    if all.isEmpty {
                        found.append("\(label) fires, and no open dose is due then")
                    } else if !candidates.contains(notification.text) {
                        found.append("\(label) names the wrong doses. Open doses then: \(names(all))")
                    } else if notification.hasTakenAction, names(candidates[0] == notification.text ? all : ruled).count != 1 {
                        found.append("\(label) has the Taken action for more than one dose")
                    }
                }
            } else if let id = followUp(notification.identifier) {
                let expected = followUpNames(date: id.date, time: id.time, minutes: id.minutes)
                let label = "pending \(notification.identifier) (\"\(notification.text.body)\")"
                if expected.isEmpty {
                    found.append("\(label) has no dose that needs a follow-up")
                } else if notification.text != text(.again, expected) {
                    found.append("\(label) names the wrong doses. They are: \(expected)")
                } else if notification.hasTakenAction, expected.count != 1 {
                    found.append("\(label) has the Taken action for more than one dose")
                }
            } else {
                found.append("pending request with an unknown identifier \(notification.identifier)")
            }
        }

        // The delivered notifications.
        for delivery in shown.values.sorted(by: { $0.notification.identifier < $1.notification.identifier }) {
            found += violations(of: delivery, at: now)
        }

        if phone.checks.coverage, device.authorization == .authorized { found += coverage(pending: Array(pending.values), now: now) }
        if phone.checks.alarms { found += await alarms(now: now) }
        return found
    }

    /// The violations of one delivered notification, at the time `at`. Called at the delivery, and after each run.
    func violations(of delivery: SimDelivery, at now: Date? = nil) -> [String] {
        let notification = delivery.notification
        let at = now ?? delivery.date
        let zone = delivery.deviceZone
        let label = "delivered \(notification.identifier) (\"\(notification.text.body)\") at \(Self.format(delivery.date, zone))"
        let today = LocalDate(at, in: device.zone)
        if let id = series(notification.identifier) {
            let named: NamedTimeZone = id.zone == "device" ? zone : ((try? NamedTimeZone(identifier: id.zone)) ?? zone)
            let date = id.date ?? LocalDate(delivery.date, in: named)
            let instant = named.resolve(id.time, on: date).earliestInstant
            let all = openDoses(at: instant)
            let ruled = rule(id.zone, all)
            if date < today.adding(days: -1) { return ["\(label) is older than yesterday and must be gone"] }
            if all.isEmpty { return ["\(label) names no open dose: every dose of it is recorded, archived, paused, or deleted"] }
            let candidates = [text(.due, names(all)), text(.due, names(ruled))]
            if !candidates.contains(notification.text) {
                return ["\(label) names \"\(notification.text.body)\", but the open doses are \(names(all))"]
            }
            return []
        }
        if let id = followUp(notification.identifier) {
            if id.date < today.adding(days: -1) { return ["\(label) is older than yesterday and must be gone"] }
            let expected = followUpNames(date: id.date, time: id.time, minutes: id.minutes)
            if expected.isEmpty { return ["\(label) has no dose that needs a follow-up"] }
            if notification.text != text(.again, expected) {
                return ["\(label) names \"\(notification.text.body)\", but the doses are \(expected)"]
            }
            return []
        }
        return ["\(label) has an unknown identifier"]
    }

    // MARK: Coverage

    private func coverage(pending: [SimNotification], now: Date) -> [String] {
        var found: [String] = []
        let zone = device.zone
        let horizon = now.addingTimeInterval(phone.checks.coverageHours * 3600)
        for dose in truth.doses(from: now, through: horizon, deviceZone: zone)
        where truth.isOpen(dose) && !dose.item.isPaused && !isCovered(dose.item) {
            let at = openDoses(at: dose.instant)
            let covered = pending.contains { notification in
                guard let id = series(notification.identifier) else { return false }
                let fires = FakeNotificationCenter.fireDates(
                    of: notification.trigger, after: dose.instant.addingTimeInterval(-1), through: dose.instant, deviceZone: zone
                )
                guard fires.contains(dose.instant) else { return false }
                let ruled = rule(id.zone, at)
                let includes = ruled.contains { $0.item.id == dose.item.id }
                return notification.text == text(.due, names(at)) || (includes && notification.text == text(.due, names(ruled)))
            }
            if !covered {
                found.append("no reminder for \(dose.item.name) at \(Self.format(dose.instant, zone))")
            }
        }
        if phone.checks.followUpCoverage { found += followUpCoverage(pending: pending, now: now) }
        return found
    }

    /// Every follow-up that the settings ask for in the next hours is pending. The limit of 64 can cut the rest.
    private func followUpCoverage(pending: [SimNotification], now: Date) -> [String] {
        var found: [String] = []
        let horizon = now.addingTimeInterval(phone.checks.followUpHours * 3600)
        let ids = Set(pending.map(\.identifier))
        let zone = device.zone
        for item in truth.items where !item.isArchived && !item.isPaused {
            guard let setting = item.followUp else { continue }
            for dose in truth.doses(from: now.addingTimeInterval(-86_400), through: horizon.addingTimeInterval(86_400), deviceZone: zone)
            where dose.item.id == item.id && truth.isOpen(dose) {
                let named = dose.zone
                for number in 1...setting.count.limit {
                    let minutes = number * setting.interval.rawValue
                    let fire = dose.instant.addingTimeInterval(Double(minutes) * 60)
                    guard fire > now, fire <= horizon else { continue }
                    guard followUpNames(date: dose.date, time: dose.time, minutes: minutes).contains(item.name) else { continue }
                    let group = dose.rule == .device ? "device@" + named.identifier : named.identifier
                    let id = "followup|\(group)|\(String(format: "%04d-%02d-%02d", dose.date.year, dose.date.month, dose.date.day))|\(String(format: "%02d:%02d", dose.time.hour, dose.time.minute))|+\(minutes)"
                    if !ids.contains(id) { found.append("no follow-up \(id) for \(item.name)") }
                }
            }
        }
        return found
    }

    // MARK: Alarms

    private func alarms(now: Date) async -> [String] {
        var found: [String] = []
        let waiting = await phone.alarmCenter.alarms.values
        for alarm in waiting.sorted(by: { $0.fireDate < $1.fireDate }) {
            let doses = openDoses(at: alarm.fireDate, covered: true)
            let expected = names(doses)
            let label = "alarm at \(Self.format(alarm.fireDate, device.zone)) (\(alarm.names ?? []))"
            if doses.isEmpty {
                found.append("\(label) waits, and no open dose of an alarm item is due then")
            } else if (alarm.names ?? []) != (showsNames ? expected : []) {
                found.append("\(label) names the wrong doses. They are: \(expected)")
            }
        }
        let horizon = now.addingTimeInterval(7 * 86_400)
        let held = Set(waiting.map(\.fireDate))
        for dose in truth.doses(from: now, through: horizon, deviceZone: device.zone)
        where truth.isOpen(dose) && !dose.item.isPaused && isCovered(dose.item) && !held.contains(dose.instant) {
            found.append("no alarm for \(dose.item.name) at \(Self.format(dose.instant, device.zone))")
        }
        return found
    }

    // MARK: Output

    func dump() async -> String {
        let zone = device.zone
        var lines = ["now \(Self.format(device.now, zone))", "pending:"]
        for notification in await phone.center.pending.values.sorted(by: { $0.identifier < $1.identifier }) {
            let next = FakeNotificationCenter.nextFire(of: notification.trigger, after: device.now, deviceZone: zone)
            lines.append("  \(notification.identifier) \"\(notification.text.body)\" next \(next.map { Self.format($0, zone) } ?? "never")")
        }
        lines.append("delivered:")
        for delivery in await phone.center.shown.values.sorted(by: { $0.date < $1.date }) {
            lines.append("  \(delivery.notification.identifier) \"\(delivery.notification.text.body)\" at \(Self.format(delivery.date, zone))")
        }
        return lines.joined(separator: "\n")
    }

    static func format(_ date: Date, _ zone: NamedTimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = zone.systemZone
        return formatter.string(from: date)
    }
}
