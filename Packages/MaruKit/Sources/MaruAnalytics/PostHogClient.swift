import Foundation
import MaruCore

/// Where the events go: the project key and the host of a PostHog project.
public struct PostHogConfiguration: Sendable, Equatable {
    public let apiKey: String
    public let host: URL

    /// `nil` for an empty key or a host that is not an https URL. The app then uses the null client.
    public init?(apiKey: String, host: String) {
        let key = apiKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, let host = URL(string: host.trimmingCharacters(in: .whitespaces)),
              host.scheme == "https", host.host() != nil
        else { return nil }
        self.apiKey = key
        self.host = host
    }
}

/// A minimal sender to the PostHog capture API (D052). It is not the PostHog SDK, so no automatic capture exists to
/// switch off (spec 11.4): it sends only the events that the app gives it, with the fields of `AnalyticsEvent`, the
/// install ID, the app version, the major version of iOS, the region setting of the device (D064), the language of the
/// app, the device family (D077), the channel of the install, and a random ID for each event (D144).
///
/// - The events wait in memory. At most `maxQueued` stay, and the oldest go first. An event older than `maxAge` goes.
/// - One request carries up to `batchSize` events, a few seconds after the first event, so a burst is one request.
///   `flush` sends without that wait, when the app leaves the front (D144).
/// - After a failed request the client sends nothing for `retryDelay`. It has no timer or loop that wakes the
///   device: the next event, the next exit from the app, or the next launch tries again (T44).
/// - The queue is not on disk. A lost analytics event costs nothing, and no health record depends on it. The daily summary
///   stays on disk in `AnalyticsService` until the server confirms it (D144).
public final class PostHogClient: AnalyticsClient, @unchecked Sendable {
    public typealias Send = @Sendable (URLRequest) async throws -> Int

    static let installIDKey = "analytics.installID"
    static let maxQueued = 100
    static let batchSize = 20
    static let maxAge: TimeInterval = 3 * 24 * 3600
    static let retryDelay: TimeInterval = 300

    private struct Pending {
        let id: UUID
        let name: String
        let properties: [String: Any]
        let time: Date
        /// Runs after the server confirms the event.
        let acknowledged: (@Sendable () -> Void)?
    }

    private let configuration: PostHogConfiguration
    private let defaults: UserDefaults
    private let appVersion: String
    private let osMajor: Int
    private let region: String?
    private let language: String
    private let device: String
    private let send: Send
    private let flushDelay: Duration
    private let readChannel: @Sendable () async -> AnalyticsChannel?
    private let lock = NSLock()
    private var queue: [Pending] = []
    /// The wait before the next request. `flush` cancels it.
    private var delay: Task<Void, Never>?
    /// The wait and the request that run now. A second request of the same events cannot start beside it.
    private var sending: Task<Void, Never>?
    /// `nil` until the system answers. A request reads it when it starts, so an event that waited gets the answer too.
    private var channel: AnalyticsChannel?
    /// The read that runs now. `reset` cancels it.
    private var channelRead: Task<Void, Never>?
    private var retryAfter = Date.distantPast
    /// A `reset` ends this client. A late task of an old event finds the flag and sends nothing.
    private var isStopped = false

    public init(
        configuration: PostHogConfiguration,
        appVersion: String,
        osMajor: Int,
        regionCode: String?,
        language: String? = nil,
        device: DeviceFamily = .other,
        defaults: UserDefaults = .standard,
        flushDelay: Duration = .seconds(5),
        send: @escaping Send = PostHogClient.urlSessionSend,
        channel: @escaping @Sendable () async -> AnalyticsChannel? = { nil }
    ) {
        self.configuration = configuration
        self.appVersion = appVersion
        self.osMajor = osMajor
        region = Self.regionField(regionCode)
        self.language = Self.languageField(language)
        self.device = device.rawValue
        self.defaults = defaults
        self.flushDelay = flushDelay
        readChannel = channel
        self.send = send
    }

    /// An ephemeral session keeps no cookie and no cache. It does not wait for a connection.
    public static let urlSessionSend: Send = { request in
        let (_, response) = try await session.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    /// The region setting of the device as two letters `A` to `Z`, in upper case (D064). `nil` for a missing value and
    /// for any other form, such as the UN M.49 code `419`. The event then has no region field.
    static func regionField(_ regionCode: String?) -> String? {
        // Check the letters before the change of case: an upper-case form can turn one other letter into two ASCII letters.
        guard let code = regionCode, code.unicodeScalars.count == 2,
              code.unicodeScalars.allSatisfy({ ("A"..."Z").contains($0) || ("a"..."z").contains($0) })
        else { return nil }
        return code.uppercased()
    }

    /// The device family. The app reads it from the system. Any other device, such as a Mac, is `other`.
    public enum DeviceFamily: String, Sendable {
        case iphone, ipad, other
    }

    /// The languages of the app (D051, D059). The app sends one of them, or `other`, never the full language list.
    static let languages = ["en", "zh-Hans", "ja", "ko", "es", "de"]

    /// The language that the app shows, as one of `languages`, else `other` (D077).
    static func languageField(_ language: String?) -> String {
        guard let language else { return "other" }
        return languages.first { $0 == language } ?? "other"
    }

    /// The pseudonymous install ID. It is made at the first event after consent, and `reset` removes it (spec 11.3).
    private var installID: String {
        if let id = defaults.string(forKey: Self.installIDKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Self.installIDKey)
        return id
    }

    public func capture(_ event: AnalyticsEvent) {
        enqueue(event, id: UUID(), time: Date(), acknowledged: nil)
    }

    public func capture(_ event: AnalyticsEvent, id: UUID, time: Date, acknowledged: @escaping @Sendable () -> Void) {
        enqueue(event, id: id, time: time, acknowledged: acknowledged)
    }

    private func enqueue(_ event: AnalyticsEvent, id: UUID, time: Date, acknowledged: (@Sendable () -> Void)?) {
        var properties: [String: Any] = [
            // The server makes no person profile and no location from the address.
            "$process_person_profile": false,
            "$geoip_disable": true,
            "app_version": appVersion,
            "ios_major": osMajor,
            "app_language": language,
            "device": device,
        ]
        // A setting of the device, not a place. The server still makes no location from the address.
        if let region { properties["region"] = region }
        for (field, value) in event.properties {
            switch value {
            case let .text(text): properties[field] = text
            case let .flag(flag): properties[field] = flag
            case let .count(count): properties[field] = count
            }
        }
        lock.lock()
        defer { lock.unlock() }
        guard !isStopped else { return }
        properties["distinct_id"] = installID
        queue.append(Pending(id: id, name: event.name, properties: properties, time: time, acknowledged: acknowledged))
        // The oldest plain events go first. An event that waits for a confirmation stays, so its owner can trust that it waits.
        var extra = queue.count - Self.maxQueued
        queue.removeAll { pending in
            guard extra > 0, pending.acknowledged == nil else { return false }
            extra -= 1
            return true
        }
        readChannelIfNeeded()
        scheduleFlush()
    }

    public func flush() async {
        while let run = lock.withLock({ () -> Task<Void, Never>? in
            scheduleFlush()
            delay?.cancel()
            return sending
        }) {
            await run.value
        }
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        isStopped = true
        channelRead?.cancel()
        channelRead = nil
        queue.removeAll()
        defaults.removeObject(forKey: Self.installIDKey)
    }

    /// The number of queued events. For tests.
    var queuedCount: Int {
        lock.withLock { queue.count }
    }

    /// Call with the lock held. Nothing waits for the read, so an event never waits for StoreKit (spec 9, D144). A read that
    /// gives no answer runs again with the next event.
    private func readChannelIfNeeded() {
        guard channel == nil, channelRead == nil else { return }
        channelRead = Task { [readChannel] in
            guard !Task.isCancelled else { return }
            let answer = await readChannel()
            lock.withLock {
                guard !isStopped else { return }
                channel = answer
                channelRead = nil
            }
        }
    }

    /// Call with the lock held.
    private func scheduleFlush() {
        guard sending == nil, !isStopped, !queue.isEmpty, Date() >= retryAfter else { return }
        // A cancelled sleep ends the wait. The request stays in another task, so the cancel does not reach it.
        let wait = Task<Void, Never> { [flushDelay] in
            try? await Task.sleep(for: flushDelay)
        }
        delay = wait
        sending = Task {
            await wait.value
            await sendBatch()
        }
    }

    /// Sends one batch. It ends the `sending` state that `scheduleFlush` started.
    private func sendBatch() async {
        let (batch, channel) = lock.withLock {
            let oldest = Date().addingTimeInterval(-Self.maxAge)
            queue.removeAll { $0.time < oldest && $0.acknowledged == nil }
            return (Array(queue.prefix(Self.batchSize)), self.channel ?? .unknown)
        }
        guard !batch.isEmpty else {
            lock.withLock { sending = nil }
            return
        }
        guard let request = request(for: batch, channel: channel) else {
            lock.withLock {
                sending = nil
                retryAfter = Date().addingTimeInterval(Self.retryDelay)
            }
            return
        }
        let status = try? await send(request)
        let confirmed = lock.withLock { () -> [Pending] in
            sending = nil
            guard !isStopped else { return [] }
            let isConfirmed: Bool
            switch status {
            case let status? where (200..<300).contains(status):
                isConfirmed = true
            case let status? where (400..<500).contains(status) && status != 408 && status != 429:
                // The server refuses the batch for good, for example with a wrong key. A retry cannot help.
                isConfirmed = false
            default:
                retryAfter = Date().addingTimeInterval(Self.retryDelay)
                return []
            }
            queue.removeAll { sent in batch.contains { $0.id == sent.id } }
            scheduleFlush()
            return isConfirmed ? batch : []
        }
        for event in confirmed { event.acknowledged?() }
    }

    private func request(for batch: [Pending], channel: AnalyticsChannel) -> URLRequest? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let events: [[String: Any]] = batch.map {
            var properties = $0.properties
            properties["channel"] = channel.rawValue
            // With the same time, the same `uuid` tells the server that a repeat send is one event (D144).
            return [
                "uuid": $0.id.uuidString.lowercased(), "event": $0.name, "properties": properties,
                "timestamp": formatter.string(from: $0.time),
            ]
        }
        let body: [String: Any] = ["api_key": configuration.apiKey, "batch": events]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: configuration.host.appending(path: "batch"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return request
    }
}
