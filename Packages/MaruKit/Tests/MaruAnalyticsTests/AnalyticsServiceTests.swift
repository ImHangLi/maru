import Foundation
import MaruCore
import Testing
@testable import MaruAnalytics

private final class RecordingClient: AnalyticsClient, @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [AnalyticsEvent] = []
    private var storedResets = 0
    var events: [AnalyticsEvent] { lock.withLock { storedEvents } }
    var resets: Int { lock.withLock { storedResets } }
    func capture(_ event: AnalyticsEvent) { lock.withLock { storedEvents.append(event) } }
    func reset() { lock.withLock { storedResets += 1 } }
}

private func isolatedDefaults() throws -> (UserDefaults, () -> Void) {
    let suite = "analytics-service-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (defaults, { defaults.removePersistentDomain(forName: suite) })
}

@Suite("Analytics lifecycle (spec 11.3, T41, T43, T44)")
@MainActor
struct AnalyticsServiceTests {
    @Test func noClientBeforeConsentAndOffClearsEverything() throws {
        let (defaults, cleanUp) = try isolatedDefaults()
        defer { cleanUp() }
        let client = RecordingClient()
        var madeClients = 0
        let service = AnalyticsService(
            isAvailable: true,
            preference: AnalyticsPreference(defaults: defaults, regionCode: "DE"),
            defaults: defaults
        ) {
            madeClients += 1
            return client
        }

        // No consent: no client exists, and no event or usage flag is kept (T41).
        service.capture(.feedbackOpened)
        service.markUsed(.record)
        #expect(madeClients == 0 && client.events.isEmpty)
        #expect(defaults.object(forKey: "analytics.usage.day") == nil)

        service.setOn(true)
        let monday = Date(timeIntervalSince1970: 1_790_000_000)
        service.markUsed(.record, at: monday)
        service.markUsed(.history, at: monday)
        #expect(client.events.isEmpty)
        // The summary of a day goes out on a later day, with the flags of that day only.
        service.sendPendingUsage(at: monday.addingTimeInterval(2 * 86_400))
        let summary = try #require(client.events.first)
        #expect(summary.properties["used_record"] == .flag(true))
        #expect(summary.properties["used_widget"] == .flag(false))

        // Off: the client resets, and the local usage state goes (T43).
        service.markUsed(.widget, at: monday.addingTimeInterval(3 * 86_400))
        service.setOn(false)
        #expect(client.resets == 1)
        #expect(defaults.object(forKey: "analytics.usage.flags") == nil)
        service.capture(.feedbackOpened)
        #expect(client.events.count == 1)
    }

    @Test func aFailingNetworkKeepsABoundedQueueAndRetriesLate() async throws {
        let (defaults, cleanUp) = try isolatedDefaults()
        defer { cleanUp() }
        let configuration = try #require(PostHogConfiguration(apiKey: "phc_test", host: "https://eu.i.posthog.com"))
        let attempts = Counter()
        let client = PostHogClient(
            configuration: configuration, appVersion: "1.0", osMajor: 27, regionCode: "AU", defaults: defaults,
            flushDelay: .zero
        ) { _ in
            attempts.increment()
            throw URLError(.notConnectedToInternet)
        }
        for _ in 0..<250 {
            client.capture(.feedbackOpened)
        }
        #expect(client.queuedCount == PostHogClient.maxQueued)
        try await Task.sleep(for: .milliseconds(200))
        // One failed request, then silence until the retry delay ends (T44). The record of the user is not involved.
        #expect(attempts.value == 1)
        #expect(client.queuedCount == PostHogClient.maxQueued)

        // Reset clears the queue and the install ID (T43).
        #expect(defaults.string(forKey: PostHogClient.installIDKey) != nil)
        client.reset()
        #expect(client.queuedCount == 0)
        #expect(defaults.string(forKey: PostHogClient.installIDKey) == nil)
    }

    @Test func aRegionThatIsNotTwoLettersIsNotSent() async throws {
        let (defaults, cleanUp) = try isolatedDefaults()
        defer { cleanUp() }
        let configuration = try #require(PostHogConfiguration(apiKey: "phc_test", host: "https://eu.i.posthog.com"))
        let bodies = Bodies()
        // The UN M.49 code of Latin America is a region setting of iOS. It is not a two-letter code (D064).
        for regionCode in ["419", "au"] {
            let client = PostHogClient(
                configuration: configuration, appVersion: "1.0", osMajor: 27, regionCode: regionCode,
                defaults: defaults, flushDelay: .seconds(60)
            ) { request in
                bodies.append(request.httpBody ?? Data())
                return 200
            }
            client.capture(.feedbackOpened)
            await client.flush()
        }
        let regions = try bodies.value.map { body in
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let batch = try #require(json["batch"] as? [[String: Any]])
            let properties = try #require(batch.first?["properties"] as? [String: Any])
            #expect(properties["$geoip_disable"] as? Bool == true)
            return properties["region"] as? String
        }
        #expect(regions == [nil, "AU"])
    }
}

private final class Bodies: @unchecked Sendable {
    private let lock = NSLock()
    private var bodies: [Data] = []
    var value: [Data] { lock.withLock { bodies } }
    func append(_ body: Data) { lock.withLock { bodies.append(body) } }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
