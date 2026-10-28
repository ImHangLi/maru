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
/// 5. Every pending request has a category that its doses allow, and the time-sensitive level (D090). A request with a group action
///    names two or more open items and shows the names.
/// 6. A snooze of the user stands as one pending request while its group has an open dose, and it pauses the follow-ups of the group
///    until its time (D090).
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
        // A reminder with group actions names every item, so its text has no "and N more" (D090).
        phone.center.text(for: ReminderContent(
            kind: kind, names: showsNames ? names.map { ReminderName(item: $0) } : nil, category: showsNames && names.count >= 2 ? .group : .snooze
        ))
    }

    // MARK: Independent calendar rules
    // The oracle does not call production helpers for dates. It uses Foundation only.

    private func calendar(_ zone: NamedTimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone.systemZone
        return calendar
    }

    /// 01:00 on the day after `date` in `zone`: the follow-ups stop, and the "Taken" action of a follow-up stops (D039).
    private func oneAMAfter(_ date: LocalDate, in zone: NamedTimeZone) -> Date {
        let calendar = calendar(zone)
        let next = calendar.date(from: DateComponents(year: date.year, month: date.month, day: date.day, hour: 12))!
            .addingTimeInterval(86_400)
        let parts = calendar.dateComponents([.year, .month, .day], from: next)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 1, minute: 0))!
    }

    /// Today shows the doses of today in their zone. A notification of yesterday's dose can stay until 01:00 of today.
    private func isVisible(_ date: LocalDate, at now: Date, in zone: NamedTimeZone) -> Bool {
        let parts = calendar(zone).dateComponents([.year, .month, .day], from: now)
        let today = (parts.year!, parts.month!, parts.day!)
        if (date.year, date.month, date.day) == today { return true }
        let yesterday = calendar(zone).dateComponents(
            [.year, .month, .day], from: now.addingTimeInterval(-86_400)
        )
        return (date.year, date.month, date.day) == (yesterday.year!, yesterday.month!, yesterday.day!)
            && now < oneAMAfter(date, in: zone)
    }

    private func baseID(_ identifier: String) -> String { Self.base(of: identifier) }

    /// The identifier without its generation (`|g<digits>` at the end).
    static func base(of identifier: String) -> String {
        // `|g<12 digits>r<4 hex>` at the end.
        guard let range = identifier.range(of: "|g", options: .backwards) else { return identifier }
        let tail = identifier[range.upperBound...].split(separator: "r", omittingEmptySubsequences: false)
        guard tail.count == 2, tail[0].count == 12, tail[0].allSatisfy(\.isNumber), tail[1].count == 4 else { return identifier }
        return String(identifier[..<range.lowerBound])
    }

    // MARK: Identifier parts

    private struct SeriesID {
        let zone: String
        let time: WallClockTime
        let date: LocalDate?
    }

    private func series(_ identifier: String) -> SeriesID? {
        let parts = baseID(identifier).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == "series" else { return nil }
        return SeriesID(zone: parts[1], time: Phone.wallClock(parts[2]), date: Self.parseDate(parts[3]))
    }

    private struct FollowUpID {
        let zone: String
        let date: LocalDate
        let time: WallClockTime
        /// The delay after the dose time. `nil` for the request of a snooze.
        let minutes: Int?
    }

    private func followUp(_ identifier: String) -> FollowUpID? {
        let parts = baseID(identifier).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 5, parts[0] == "followup", let date = Self.parseDate(parts[2]) else { return nil }
        return FollowUpID(
            zone: parts[1], date: date, time: Phone.wallClock(parts[3]), minutes: parts[4] == "snooze" ? nil : Int(parts[4].dropFirst())!
        )
    }

    /// The plan date (when the identifier has one) and the time of day of a series request or of a follow-up.
    static func parts(of identifier: String) -> (date: LocalDate?, time: WallClockTime) {
        let parts = Oracle.base(of: identifier).split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if parts[0] == "followup" { return (parseDate(parts[2]), Phone.wallClock(parts[3])) }
        return (parseDate(parts[3]), Phone.wallClock(parts[2]))
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
                let stop = min(oneAMAfter(date, in: zone), later ?? .distantFuture)
                guard fire < stop else { continue }
                doses.append(SimDose(item: item, slot: slot.id, date: date, time: time, instant: slotInstant, zone: zone, rule: item.zone))
            }
        }
        return names(doses)
    }

    // MARK: Snoozes and categories (D090)

    /// The snooze of the user for the dose group of `date` and `time`, while its time is still to come.
    private func liveSnooze(date: LocalDate, time: WallClockTime, now: Date) -> SimSnooze? {
        truth.snoozes.first { $0.date == date && $0.time == time && $0.fireAt > now }
    }

    /// The open doses of the group of `date` and `time`: every item that reminds, in any zone rule (as `followUpNames` reads them).
    private func openGroupDoses(date: LocalDate, time: WallClockTime) -> [SimDose] {
        truth.openDoses(on: date, at: time, deviceZone: device.zone)
    }

    /// I8 and I9: the category of a request that names `count` open items, and its level. A request names a group action only when
    /// it names two or more items and shows the names, because only then can the user see what the action records.
    /// A follow-up of a group of one item can have the actions of one item, and a follow-up that names one item of a larger group
    /// has only the snooze.
    private func presentationViolation(_ presentation: ReminderPresentation?, named count: Int, isFirstReminder: Bool) -> String? {
        guard let presentation else { return "has a category that this build does not register" }
        guard presentation.level == .timeSensitive else { return "has the level \(presentation.level), not time sensitive" }
        let allowed: Set<ReminderCategory>
        switch (count >= 2, showsNames) {
        case (true, true): allowed = [.group]
        case (true, false): allowed = [.snooze]
        case (false, _): allowed = isFirstReminder && showsNames ? [.single] : [.single, .snooze]
        }
        return allowed.contains(presentation.category)
            ? nil : "has the category \(presentation.category) for \(count) named doses, names shown: \(showsNames)"
    }

    /// A pending request of a snooze of the user (I10).
    private func snoozeViolations(_ notification: SimNotification, _ id: FollowUpID, label: String, now: Date) -> [String] {
        guard let snooze = truth.snoozes.first(where: { $0.date == id.date && $0.time == id.time }) else {
            return ["\(label) is a snooze that the user did not ask for"]
        }
        var found: [String] = []
        if case let .instant(fire) = notification.trigger, fire != max(snooze.fireAt, now.addingTimeInterval(1)) {
            found.append("\(label) fires at \(Self.format(fire, device.zone)), and the snooze is for \(Self.format(snooze.fireAt, device.zone))")
        }
        let doses = openGroupDoses(date: id.date, time: id.time)
        if doses.isEmpty {
            found.append("\(label) is a snooze with no open dose in its group")
        } else {
            if notification.text != text(.due, names(doses)) {
                found.append("\(label) names the wrong doses. They are: \(names(doses))")
            }
            if let wrong = presentationViolation(notification.presentation, named: names(doses).count, isFirstReminder: false) {
                found.append("\(label) \(wrong)")
            }
        }
        return found
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
                    } else if let wrong = presentationViolation(
                        notification.presentation, named: names(candidates[0] == notification.text ? all : ruled).count, isFirstReminder: true
                    ) {
                        found.append("\(label) \(wrong)")
                    }
                }
            } else if let id = followUp(notification.identifier) {
                let label = "pending \(notification.identifier) (\"\(notification.text.body)\")"
                guard let minutes = id.minutes else {
                    found += snoozeViolations(notification, id, label: label, now: now)
                    continue
                }
                let expected = followUpNames(date: id.date, time: id.time, minutes: minutes)
                if expected.isEmpty {
                    found.append("\(label) has no dose that needs a follow-up")
                } else if notification.text != text(.again, expected) {
                    found.append("\(label) names the wrong doses. They are: \(expected)")
                } else if let wrong = presentationViolation(notification.presentation, named: expected.count, isFirstReminder: false) {
                    found.append("\(label) \(wrong)")
                }
                // A snooze pauses the follow-ups of its group until its time (D090).
                if case let .instant(fire) = notification.trigger,
                   let snooze = liveSnooze(date: id.date, time: id.time, now: now), fire <= snooze.fireAt {
                    found.append("\(label) fires at \(Self.format(fire, zone)), before the snooze of the user ends at \(Self.format(snooze.fireAt, zone))")
                }
            } else if !notification.identifier.hasPrefix("other|") {
                // A request that another part of the app owns is not checked and not touched.
                found.append("pending request with an unknown identifier \(notification.identifier)")
            }
        }

        // A snooze of the user has its request while its group has an open dose (I10).
        if device.authorization == .authorized {
            for snooze in truth.snoozes where snooze.fireAt > now && !openGroupDoses(date: snooze.date, time: snooze.time).isEmpty {
                let has = pending.values.contains {
                    followUp($0.identifier).map { $0.minutes == nil && $0.date == snooze.date && $0.time == snooze.time } ?? false
                }
                if !has { found.append("no snooze request for \(snooze.date.dayText) \(snooze.time) at \(Self.format(snooze.fireAt, zone))") }
            }
        }

        // One generation of each base stays after a run (D086).
        let bases = Dictionary(grouping: pending.values.map(\.identifier), by: baseID)
        // While the system still holds a removal that the app asked for, an older generation can still be there.
        let slow = await phone.center.hasOpenRemovals
        for (base, ids) in bases.sorted(by: { $0.key < $1.key }) where ids.count > 1 && !slow {
            found.append("pending \(base) is held \(ids.count) times")
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
        if let id = series(notification.identifier) {
            let named: NamedTimeZone = id.zone == "device" ? zone : ((try? NamedTimeZone(identifier: id.zone)) ?? zone)
            let date = id.date ?? LocalDate(delivery.date, in: named)
            let instant = named.resolve(id.time, on: date).earliestInstant
            let all = openDoses(at: instant)
            let ruled = rule(id.zone, all)
            if !isVisible(date, at: at, in: named) { return ["\(label) is of a day that Today no longer shows and must be gone"] }
            if all.isEmpty { return ["\(label) names no open dose: every dose of it is recorded, archived, paused, or deleted"] }
            let candidates = [text(.due, names(all)), text(.due, names(ruled))]
            if !candidates.contains(notification.text) {
                return ["\(label) names \"\(notification.text.body)\", but the open doses are \(names(all))"]
            }
            return []
        }
        if let id = followUp(notification.identifier) {
            let followUpZone = (try? NamedTimeZone(identifier: id.zone.replacingOccurrences(of: "device@", with: ""))) ?? zone
            if !isVisible(id.date, at: at, in: followUpZone) { return ["\(label) is of a day that Today no longer shows and must be gone"] }
            if id.minutes == nil {
                // A delivered snooze names every open dose of its group (D090).
                let expected = names(openGroupDoses(date: id.date, time: id.time))
                if expected.isEmpty { return ["\(label) is a snooze with no open dose in its group"] }
                if notification.text != text(.due, expected) {
                    return ["\(label) names \"\(notification.text.body)\", but the doses are \(expected)"]
                }
                return []
            }
            let expected = followUpNames(date: id.date, time: id.time, minutes: id.minutes!)
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
        let ids = Set(pending.map { baseID($0.identifier) })
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
                    if let snooze = liveSnooze(date: dose.date, time: dose.time, now: now), fire <= snooze.fireAt { continue }
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

    /// The instants at which a waiting alarm rings in the next days: one for an alarm of one date, many for a repeating alarm.
    private func rings(of alarm: AlarmRequest, from now: Date, days: Int) -> [Date] {
        if let repeating = alarm.repeating {
            return FakeAlarmCenter.rings(
                of: repeating, after: now, through: now.addingTimeInterval(Double(days) * 86_400), zone: device.zone
            )
        }
        return alarm.fireDate > now ? [alarm.fireDate] : []
    }

    private func alarms(now: Date) async -> [String] {
        var found: [String] = []
        let waiting = await phone.alarmCenter.alarms.values
        var held = Set<Date>()
        for alarm in waiting.sorted(by: { $0.fireDate < $1.fireDate }) {
            for fire in rings(of: alarm, from: now, days: 28) {
                if fire <= now.addingTimeInterval(7 * 86_400) { held.insert(fire) }
                let doses = openDoses(at: fire, covered: true)
                let expected = names(doses)
                let label = "alarm at \(Self.format(fire, device.zone)) (\(alarm.names ?? []))"
                if doses.isEmpty {
                    found.append("\(label) waits, and no open dose of an alarm item is due then")
                } else if (alarm.names ?? []).map(\.item) != (showsNames ? expected : []) {
                    found.append("\(label) names the wrong doses. They are: \(expected)")
                }
            }
        }
        let horizon = now.addingTimeInterval(7 * 86_400)
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
