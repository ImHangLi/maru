import Foundation
@testable import MaruCore
@testable import MaruNotifications

// MARK: - The device

/// The state of the simulated device that every part shares: the virtual clock, the time zone,
/// and the permissions. It is the world outside the app.
final class SimDevice: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    private var _zone: NamedTimeZone
    private var _authorization: ReminderAuthorization = .authorized
    private var _alarmsAllowed = true

    init(now: Date, zone: NamedTimeZone) {
        _now = now
        _zone = zone
    }

    var now: Date {
        get { lock.withLock { _now } }
        set { lock.withLock { _now = newValue } }
    }

    var zone: NamedTimeZone {
        get { lock.withLock { _zone } }
        set { lock.withLock { _zone = newValue } }
    }

    var authorization: ReminderAuthorization {
        get { lock.withLock { _authorization } }
        set { lock.withLock { _authorization = newValue } }
    }

    /// The AlarmKit permission and iOS 26. With `false`, no alarm rings, as `AlarmSupport.isAuthorized` says.
    var alarmsAllowed: Bool {
        get { lock.withLock { _alarmsAllowed } }
        set { lock.withLock { _alarmsAllowed = newValue } }
    }
}

// MARK: - The notification system

/// What a stored request fires on. The fake keeps the two trigger kinds that the app uses.
enum SimTrigger: Sendable {
    /// `UNCalendarNotificationTrigger`: the components match on the calendar of their zone, or of the device when
    /// they have none. With `repeats`, the request fires on every matching day.
    case calendar(DateComponents, repeats: Bool)
    /// `UNTimeIntervalNotificationTrigger`, already resolved to the instant at which it fires.
    case instant(Date)
}

struct SimNotification: Sendable {
    let identifier: String
    let text: ReminderText
    let userInfo: [String: String]
    let hasTakenAction: Bool
    let threadIdentifier: String?
    let trigger: SimTrigger
}

/// A notification that the system delivered, and when.
struct SimDelivery: Sendable {
    let notification: SimNotification
    let date: Date
    /// The time zone of the device at the delivery.
    let deviceZone: NamedTimeZone
}

/// A fake `UNUserNotificationCenter`. It keeps the rules of the real one that the engines depend on:
///
/// - One request for each identifier. An add with a known identifier replaces the pending request.
/// - A removal is asynchronous: it takes effect after `removalLatency` reads of the pending requests.
///   A removal that the system takes later also removes a new request with the same identifier.
/// - A repeating calendar trigger fires on every matching day. A dated trigger fires one time. A one-time request
///   leaves the pending set when it fires. A repeating request stays.
/// - A delivery puts the notification in the delivered set. A later delivery with the same identifier replaces it.
/// - Over 64 pending requests, the system keeps the 64 that fire first, and it reports no error.
/// - Notifications that are off: an add fails, and nothing is delivered.
actor FakeNotificationCenter: FollowUpCenter {
    static let limit = 64

    nonisolated let device: SimDevice
    private(set) var pending: [String: SimNotification] = [:]
    private(set) var shown: [String: SimDelivery] = [:]
    /// Every delivery since the start, in order. The oracle checks each one.
    private(set) var deliveries: [SimDelivery] = []
    private var openRemovals: [(identifiers: [String], readsLeft: Int)] = []
    /// A removal takes effect after this many reads of the pending requests. With 0, it takes effect at the call.
    var removalLatency = 0
    /// The system takes a removal and never does it.
    var dropsRemovals = false
    /// The system takes this many next adds with no error and does not keep them.
    var dropsNextAdds = 0
    /// Every add that the app made, in order.
    private(set) var addLog: [String] = []
    private(set) var removeLog: [String] = []

    init(device: SimDevice) {
        self.device = device
    }

    func setRemovalLatency(_ reads: Int) { removalLatency = reads }
    func setDropsRemovals(_ drops: Bool) { dropsRemovals = drops }
    func setDropsNextAdds(_ count: Int) { dropsNextAdds = count }

    // MARK: ReminderCenter

    func authorization() -> ReminderAuthorization { device.authorization }

    func requestAuthorization() -> ReminderAuthorization {
        if device.authorization == .notDetermined { device.authorization = .authorized }
        return device.authorization
    }

    func pendingRequests() -> [PendingReminder] {
        applyDueRemovals()
        return pending.values.map { pendingReminder($0, deliveredAt: nil) }
    }

    /// The pending requests as they are, with the removals that the system already took in but did not do.
    /// A call after the process stopped reads this, so no engine waits for a removal that nobody confirms.
    func pendingRequestsAfterQueuedRemovals() -> [PendingReminder] {
        let queued = Set(openRemovals.flatMap(\.identifiers))
        return pending.values.filter { !queued.contains($0.identifier) }.map { pendingReminder($0, deliveredAt: nil) }
    }

    func add(_ request: ReminderRequest) throws {
        let trigger = SimTrigger.calendar(request.trigger.dateComponents, repeats: request.trigger.repeats)
        try store(
            SimNotification(
                identifier: request.identifier, text: text(for: request.content), userInfo: request.userInfo,
                hasTakenAction: request.content.hasTakenAction, threadIdentifier: nil, trigger: trigger
            )
        )
    }

    func add(_ request: FollowUpRequest) throws {
        // `SystemReminderCenter` gives a time-interval trigger of `max(1, fireDate - now)`.
        let fire = max(request.fireDate, device.now.addingTimeInterval(1))
        try store(
            SimNotification(
                identifier: request.identifier, text: text(for: request.content), userInfo: request.userInfo,
                hasTakenAction: request.content.hasTakenAction, threadIdentifier: request.threadIdentifier,
                trigger: .instant(fire)
            )
        )
    }

    func remove(identifiers: [String]) {
        removeLog += identifiers
        guard !dropsRemovals else { return }
        if removalLatency > 0 {
            openRemovals.append((identifiers, removalLatency))
        } else {
            identifiers.forEach { pending[$0] = nil }
        }
    }

    nonisolated func text(for content: ReminderContent) -> ReminderText {
        content.text(locale: Locale(identifier: "en_US"))
    }

    // MARK: FollowUpCenter

    func delivered() -> [PendingReminder] {
        shown.values.map { pendingReminder($0.notification, deliveredAt: $0.date) }
    }

    func removeDelivered(identifiers: [String]) {
        identifiers.forEach { shown[$0] = nil }
    }

    // MARK: The system itself

    /// The user clears a notification, or taps its action.
    func dismiss(_ identifier: String) { shown[identifier] = nil }

    /// A request that an earlier build of the app registered. The current build did not make it.
    func inject(_ notification: SimNotification, delivered at: Date? = nil) {
        if let at {
            shown[notification.identifier] = SimDelivery(notification: notification, date: at, deviceZone: device.zone)
        } else {
            pending[notification.identifier] = notification
        }
    }

    /// Moves the clock to `time` and delivers every request that fires up to it, in the order of the instants.
    func advance(to time: Date) {
        let from = device.now
        precondition(time >= from, "the clock only moves forward")
        var events: [(Date, SimNotification)] = []
        for notification in pending.values {
            for date in Self.fireDates(of: notification.trigger, after: from, through: time, deviceZone: device.zone) {
                events.append((date, notification))
            }
        }
        events.sort { ($0.0, $0.1.identifier) < ($1.0, $1.1.identifier) }
        for (date, notification) in events {
            // A removal that the system took in earlier is done before a later fire time.
            if device.authorization == .authorized {
                let delivery = SimDelivery(notification: notification, date: date, deviceZone: device.zone)
                shown[notification.identifier] = delivery
                deliveries.append(delivery)
            }
            if case .instant = notification.trigger { pending[notification.identifier] = nil }
            if case .calendar(_, repeats: false) = notification.trigger { pending[notification.identifier] = nil }
        }
        // A one-time request whose time passed while notifications were off is gone too.
        for notification in pending.values {
            if case .instant(let date) = notification.trigger, date <= time { pending[notification.identifier] = nil }
        }
        device.now = time
    }

    // MARK: Private

    private func store(_ notification: SimNotification) throws {
        addLog.append(notification.identifier)
        guard device.authorization == .authorized else { throw SimError.notAllowed }
        guard dropsNextAdds == 0 else {
            dropsNextAdds -= 1
            return
        }
        pending[notification.identifier] = notification
        enforceLimit()
    }

    /// Over the limit, the system keeps the requests that fire first and drops the others with no error.
    private func enforceLimit() {
        guard pending.count > Self.limit else { return }
        let now = device.now
        let order = pending.values.sorted {
            let first = Self.nextFire(of: $0.trigger, after: now, deviceZone: device.zone) ?? .distantFuture
            let second = Self.nextFire(of: $1.trigger, after: now, deviceZone: device.zone) ?? .distantFuture
            return (first, $0.identifier) < (second, $1.identifier)
        }
        for dropped in order.dropFirst(Self.limit) { pending[dropped.identifier] = nil }
    }

    private func applyDueRemovals() {
        openRemovals = openRemovals.map { ($0.identifiers, $0.readsLeft - 1) }
        for removal in openRemovals where removal.readsLeft <= 0 {
            removal.identifiers.forEach { pending[$0] = nil }
        }
        openRemovals.removeAll { $0.readsLeft <= 0 }
    }

    private func pendingReminder(_ notification: SimNotification, deliveredAt: Date?) -> PendingReminder {
        PendingReminder(
            identifier: notification.identifier, userInfo: notification.userInfo, text: notification.text,
            hasTakenAction: notification.hasTakenAction, isTimeSensitive: true, deliveredAt: deliveredAt
        )
    }

    // MARK: Triggers

    static func nextFire(of trigger: SimTrigger, after time: Date, deviceZone: NamedTimeZone) -> Date? {
        fireDates(of: trigger, after: time, through: time.addingTimeInterval(400 * 86_400), deviceZone: deviceZone, limit: 1).first
    }

    /// The instants in `(after, through]` at which the trigger fires.
    static func fireDates(
        of trigger: SimTrigger, after: Date, through: Date, deviceZone: NamedTimeZone, limit: Int = .max
    ) -> [Date] {
        switch trigger {
        case let .instant(date):
            return date > after && date <= through ? [date] : []
        case let .calendar(components, repeats):
            let zone = components.timeZone ?? deviceZone.systemZone
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            guard let hour = components.hour, let minute = components.minute else { return [] }
            var result: [Date] = []
            // Every local day from the day before `after` to the day after `through`.
            var day = calendar.startOfDay(for: after.addingTimeInterval(-86_400))
            let last = calendar.startOfDay(for: through.addingTimeInterval(86_400))
            while day <= last, result.count < limit {
                let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: day)
                let matches = (components.year.map { $0 == parts.year } ?? true)
                    && (components.month.map { $0 == parts.month } ?? true)
                    && (components.day.map { $0 == parts.day } ?? true)
                    && (components.weekday.map { $0 == parts.weekday } ?? true)
                if matches,
                   let instant = calendar.date(from: DateComponents(
                       year: parts.year, month: parts.month, day: parts.day, hour: hour, minute: minute
                   )),
                   calendar.component(.hour, from: instant) == hour, calendar.component(.minute, from: instant) == minute,
                   instant > after, instant <= through {
                    result.append(instant)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            // A dated trigger that does not repeat fires one time.
            return repeats ? result : Array(result.prefix(1))
        }
    }
}

enum SimError: Error { case notAllowed }

// MARK: - The alarm system

/// A fake AlarmKit. It keeps the waiting alarms. An alarm that reaches its time rings and leaves the waiting set.
actor FakeAlarmCenter: AlarmCenter {
    private(set) var alarms: [UUID: AlarmRequest] = [:]
    private(set) var rang: [AlarmRequest] = []
    /// The system refuses to schedule an alarm.
    var schedulingFails = false
    var cancelFails = false

    func setSchedulingFails(_ value: Bool) { schedulingFails = value }
    func setCancelFails(_ value: Bool) { cancelFails = value }

    func waiting() -> Set<UUID> { Set(alarms.keys) }

    func schedule(_ request: AlarmRequest) throws {
        guard !schedulingFails else { throw SimError.notAllowed }
        alarms[request.id] = request
    }

    func cancel(_ ids: [UUID]) throws {
        guard !cancelFails else { throw SimError.notAllowed }
        ids.forEach { alarms[$0] = nil }
    }

    func advance(to time: Date) {
        for request in alarms.values.filter({ $0.fireDate <= time }).sorted(by: { $0.fireDate < $1.fireDate }) {
            rang.append(request)
            alarms[request.id] = nil
        }
    }
}
