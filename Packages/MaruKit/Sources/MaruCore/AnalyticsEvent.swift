/// One product analytics event (spec 11.5). The schema below is the only list of what can leave the device.
///
/// The init rejects an unknown event, an unknown field, and a value outside the allowed values. It never drops a field
/// in silence, so a wrong call shows at once (T45). The schema holds no item name, no dose, no intake time, and no ID
/// (spec 10, 11.2). Add a field here only with a spec change.
public struct AnalyticsEvent: Sendable, Equatable {
    public enum Value: Sendable, Equatable {
        case text(String)
        case flag(Bool)
        case count(Int)
    }

    public enum Rejection: Error, Equatable, Sendable {
        case unknownEvent(String)
        case unknownField(event: String, field: String)
        case invalidValue(event: String, field: String)
    }

    private enum Field {
        case choice([String])
        case flag
        case count(ClosedRange<Int>)

        func accepts(_ value: Value) -> Bool {
            switch (self, value) {
            case let (.choice(allowed), .text(text)): allowed.contains(text)
            case (.flag, .flag): true
            case let (.count(range), .count(count)): range.contains(count)
            default: false
            }
        }
    }

    private static let schema: [String: [String: Field]] = [
        "setup_step": ["step": .choice(["item_saved"])],
        "daily_usage_summary": [
            "day_index": .count(0...3650),
            "used_record": .flag,
            "used_history": .flag,
            "used_notification": .flag,
            "used_widget": .flag,
        ],
        "core_error": [
            "operation": .choice(["save", "read"]),
            "code": .choice(["locked", "corrupt", "newer_schema", "migration_failed", "failed"]),
        ],
        "feedback_entry": ["entry": .choice(["settings"])],
        "purchase_result": [
            "product": .choice(["supporter"]),
            "result": .choice(["purchased", "cancelled", "pending", "failed"]),
        ],
    ]

    public let name: String
    public let properties: [String: Value]

    public init(name: String, properties: [String: Value] = [:]) throws(Rejection) {
        guard let fields = Self.schema[name] else { throw .unknownEvent(name) }
        for (field, value) in properties {
            guard let allowed = fields[field] else { throw .unknownField(event: name, field: field) }
            guard allowed.accepts(value) else { throw .invalidValue(event: name, field: field) }
        }
        self.name = name
        self.properties = properties
    }

    /// For the factories below, whose inputs are enums. A test sends each factory result through the checked init.
    private init(unchecked name: String, _ properties: [String: Value] = [:]) {
        self.name = name
        self.properties = properties
    }
}

/// The app builds its events with these factories.
public extension AnalyticsEvent {
    /// A part of the app that the user used on one day (spec 11.5).
    enum UsageFlag: String, CaseIterable, Sendable {
        case record = "used_record"
        case history = "used_history"
        case notification = "used_notification"
        case widget = "used_widget"
    }

    enum Operation: String, Sendable {
        case save, read
    }

    enum ErrorCode: String, Sendable {
        case locked, corrupt, newerSchema = "newer_schema", migrationFailed = "migration_failed", failed
    }

    /// An item was saved. It does not say which item.
    static var itemSaved: AnalyticsEvent {
        AnalyticsEvent(unchecked: "setup_step", ["step": .text("item_saved")])
    }

    /// `dayIndex` counts the days from the first day of use after analytics became active. It is not the install day.
    static func dailyUsage(dayIndex: Int, used: Set<UsageFlag>) -> AnalyticsEvent {
        var properties: [String: Value] = ["day_index": .count(min(max(dayIndex, 0), 3650))]
        for flag in UsageFlag.allCases {
            properties[flag.rawValue] = .flag(used.contains(flag))
        }
        return AnalyticsEvent(unchecked: "daily_usage_summary", properties)
    }

    static func coreError(_ operation: Operation, _ code: ErrorCode) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "core_error", ["operation": .text(operation.rawValue), "code": .text(code.rawValue)])
    }

    static var feedbackOpened: AnalyticsEvent {
        AnalyticsEvent(unchecked: "feedback_entry", ["entry": .text("settings")])
    }
}
