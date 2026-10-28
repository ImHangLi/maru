import Foundation


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
        "setup_step": [
            "step": .choice(SetupStep.allCases.map(\.rawValue)),
            "mode": .choice(EditorMode.allCases.map(\.rawValue)),
            "has_reminder": .flag,
            "has_alarm": .flag,
            "has_follow_up": .flag,
            "has_amount": .flag,
            "has_note": .flag,
            "has_photo": .flag,
            "name_source": .choice(NameSource.allCases.map(\.rawValue)),
            "used_completion": .flag,
            "first_item": .flag,
            "had_changes": .flag,
            "duration": .choice(["under_30s", "30s_to_2m", "2m_to_5m", "over_5m"]),
        ],
        "daily_usage_summary": [
            "day_index": .count(0...3650),
            "used_record": .flag,
            "used_history": .flag,
            "used_notification": .flag,
            "used_widget": .flag,
            "used_reminder_action": .flag,
            "used_skip": .flag,
            "used_undo": .flag,
            "used_correction": .flag,
            "used_my_items": .flag,
            "used_item_detail": .flag,
            "used_settings": .flag,
            "family_size": .choice(["1", "2", "3_plus"]),
            "app_opens": .choice(["0", "1", "2_3", "4_6", "7_plus"]),
            "active_items": .choice(["0", "1", "2_3", "4_6", "7_plus"]),
            "has_widget": .flag,
        ],
        "core_error": [
            "operation": .choice(Operation.allCases.map(\.rawValue)),
            "code": .choice(ErrorCode.allCases.map(\.rawValue)),
            // The rule that a stored row broke, as a fixed word. It is set only for `invalid_data` and `row_skipped` (D088).
            "rule": .choice(StoredDataRule.allCases.map(\.rawValue)),
        ],
        "notification_permission": [
            "state": .choice(Permission.allCases.map(\.rawValue)),
            "previous": .choice(["unknown"] + Permission.allCases.map(\.rawValue)),
        ],
        "setting_changed": [
            "show_names": .flag,
            "app_color": .choice(ItemColor.allCases.map(\.rawValue)),
            "all_alarm": .flag,
            "all_remind_again": .choice(["off", "1", "2", "3", "5", "until_recorded"]),
            "all_remind_again_minutes": .choice(["5", "10", "15", "30", "60"]),
        ],
        "data_action": [
            "action": .choice(DataAction.allCases.map(\.rawValue)),
            "result": .choice(DataResult.allCases.map(\.rawValue)),
        ],
        "feedback_entry": ["entry": .choice(["settings"])],
        // Maru Pro (D107). The place that showed the paywall, and the end of a purchase or a restore. No item data.
        "paywall_shown": ["source": .choice(PaywallSource.allCases.map(\.rawValue))],
        "purchase_result": [
            "result": .choice(PurchaseResult.allCases.map(\.rawValue)),
            "plan": .choice(PurchasePlan.allCases.map(\.rawValue)),
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
    /// A part of the app that the user used on one day (spec 11.5). Each flag is one bit for the day. It has no time
    /// and no count.
    enum UsageFlag: String, CaseIterable, Sendable {
        case record = "used_record"
        case history = "used_history"
        /// The app opened from a tap on a reminder, or the "Taken" action of a reminder ran.
        case notification = "used_notification"
        case widget = "used_widget"
        /// The "Taken" action of a reminder recorded a dose, with no open of the app.
        case reminderAction = "used_reminder_action"
        case skip = "used_skip"
        case undo = "used_undo"
        /// A record replaced an earlier record of the same dose, for example "Change Time…".
        case correction = "used_correction"
        case myItems = "used_my_items"
        case itemDetail = "used_item_detail"
        case settings = "used_settings"
    }

    /// The local tallies of one day, sent as coarse buckets in the summary of that day.
    struct UsageDay: Sendable, Equatable {
        public var used: Set<UsageFlag>
        /// The number of times that the app came to the front on the day.
        public var opens: Int
        /// The number of active items at the last read of the day. `nil` when the app did not read them.
        public var activeItems: Int?
        /// Whether a widget of Maru was on the Home Screen at the last check of the day. `nil` when not checked.
        public var hasWidget: Bool?
        /// The number of active members of the Family at the last read of the day. `nil` when the app did not read them.
        public var familySize: Int?

        public init(
            used: Set<UsageFlag> = [], opens: Int = 0, activeItems: Int? = nil, hasWidget: Bool? = nil, familySize: Int? = nil
        ) {
            self.used = used
            self.opens = opens
            self.activeItems = activeItems
            self.hasWidget = hasWidget
            self.familySize = familySize
        }
    }

    enum SetupStep: String, CaseIterable, Sendable {
        case editorOpened = "editor_opened"
        case itemSaved = "item_saved"
        /// The edit screen closed with no save. It is not called "abandoned": the user can come back (spec 11.1).
        case editorClosed = "editor_closed"
        case scanOpened = "scan_opened"
        case scanUsed = "scan_used"
        /// The camera is off for Maru, or the user refused it.
        case scanBlocked = "scan_blocked"
    }

    enum EditorMode: String, CaseIterable, Sendable {
        case new, edit, replace
    }

    /// How the name of a new item got into the field the last time. A key press after it keeps the source.
    enum NameSource: String, CaseIterable, Sendable {
        case typed, suggestion, scan
    }

    /// One save on the edit screen. It holds flags, never a name, an amount, a time, or the kind or count of doses
    /// of the plan, because those describe the regimen of the user (D077).
    struct ItemSetup: Sendable {
        public var mode: EditorMode
        /// The plan has at least one reminder time.
        public var hasReminder: Bool
        /// The item has the alarm option on (D079).
        public var hasAlarm: Bool
        /// The item has follow-ups on (D079). Not their count or their interval.
        public var hasFollowUp: Bool
        public var hasAmount: Bool
        public var hasNote: Bool
        public var hasPhoto: Bool
        /// Only for a new item or a replacement.
        public var nameSource: NameSource?
        public var usedCompletion: Bool
        public var isFirstItem: Bool
        public var duration: TimeInterval

        public init(
            mode: EditorMode, hasReminder: Bool, hasAlarm: Bool, hasFollowUp: Bool, hasAmount: Bool, hasNote: Bool,
            hasPhoto: Bool, nameSource: NameSource?, usedCompletion: Bool, isFirstItem: Bool, duration: TimeInterval
        ) {
            self.mode = mode
            self.hasReminder = hasReminder
            self.hasAlarm = hasAlarm
            self.hasFollowUp = hasFollowUp
            self.hasAmount = hasAmount
            self.hasNote = hasNote
            self.hasPhoto = hasPhoto
            self.nameSource = nameSource
            self.usedCompletion = usedCompletion
            self.isFirstItem = isFirstItem
            self.duration = duration
        }
    }

    enum Operation: String, CaseIterable, Sendable {
        case save, read
        /// A run of the reminder engine.
        case schedule
        /// The label scanner.
        case scan
    }

    enum ErrorCode: String, CaseIterable, Sendable {
        case locked, corrupt, newerSchema = "newer_schema", migrationFailed = "migration_failed", failed
        /// The system holds no room for the reminder of a plan.
        case tooMany = "too_many"
        /// The plan is saved, and the system does not hold its reminder.
        case notSet = "not_set"
        /// The system did not confirm a removal.
        case notConfirmed = "not_confirmed"
        /// The run of the reminder engine stopped, because a stored row did not load (D088).
        case invalidData = "invalid_data"
        /// A stored row did not load and the app skipped it. Every other item kept its reminders (D088).
        case rowSkipped = "row_skipped"
    }

    enum Permission: String, CaseIterable, Sendable {
        case notAsked = "not_asked"
        case allowed, denied
        /// Delivered quietly, with no banner and no sound.
        case quiet
    }

    enum DataAction: String, CaseIterable, Sendable {
        case export, backup, restore
    }

    enum DataResult: String, CaseIterable, Sendable {
        /// The file was made, or the restore committed.
        case done
        case failed
        case cancelled
        /// The picked file is not a Maru backup.
        case invalidFile = "invalid_file"
        /// The backup comes from a newer version of Maru.
        case newerFile = "newer_file"
        /// The restore committed, and the storage medium did not confirm it.
        case notConfirmed = "not_confirmed"
    }

    /// The place that showed the paywall of Maru Pro (D107).
    enum PaywallSource: String, CaseIterable, Sendable {
        /// The one offer after the first save of an item with a time.
        case firstValue = "first_value"
        /// The card at the bottom of Today.
        case day7Card = "day7_card"
        /// A tap on a Pro feature by a free user.
        case feature
        case settings
        /// A free user chose an app icon other than the default (D112).
        case icons
        /// A free user chose a reminder sound other than the default (D112).
        case sounds
        /// A free user tried to add a second member of the Family (D122).
        case family
    }

    /// The end of a purchase or a restore (D107).
    enum PurchaseResult: String, CaseIterable, Sendable {
        case purchased, cancelled, pending, failed, restored
    }

    /// The plan of a purchase. It is not a price and not an Apple ID.
    enum PurchasePlan: String, CaseIterable, Sendable {
        case yearly, lifetime
    }

    static func paywallShown(_ source: PaywallSource) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "paywall_shown", ["source": .text(source.rawValue)])
    }

    /// `plan` is `nil` for a restore that found no purchase, or a failure before a plan was known.
    static func purchaseResult(_ result: PurchaseResult, plan: PurchasePlan?) -> AnalyticsEvent {
        var properties: [String: Value] = ["result": .text(result.rawValue)]
        if let plan { properties["plan"] = .text(plan.rawValue) }
        return AnalyticsEvent(unchecked: "purchase_result", properties)
    }

    static func setupStep(_ step: SetupStep, mode: EditorMode) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setup_step", ["step": .text(step.rawValue), "mode": .text(mode.rawValue)])
    }

    /// An item was saved. It does not say which item.
    static func itemSaved(_ setup: ItemSetup) -> AnalyticsEvent {
        var properties: [String: Value] = [
            "step": .text(SetupStep.itemSaved.rawValue),
            "mode": .text(setup.mode.rawValue),
            "has_reminder": .flag(setup.hasReminder),
            "has_alarm": .flag(setup.hasAlarm),
            "has_follow_up": .flag(setup.hasFollowUp),
            "has_amount": .flag(setup.hasAmount),
            "has_note": .flag(setup.hasNote),
            "has_photo": .flag(setup.hasPhoto),
            "used_completion": .flag(setup.usedCompletion),
            "first_item": .flag(setup.isFirstItem),
            "duration": .text(durationBucket(setup.duration)),
        ]
        if let source = setup.nameSource { properties["name_source"] = .text(source.rawValue) }
        return AnalyticsEvent(unchecked: "setup_step", properties)
    }

    /// The edit screen closed with no save.
    static func editorClosed(mode: EditorMode, hadChanges: Bool, duration: TimeInterval) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setup_step", [
            "step": .text(SetupStep.editorClosed.rawValue),
            "mode": .text(mode.rawValue),
            "had_changes": .flag(hadChanges),
            "duration": .text(durationBucket(duration)),
        ])
    }

    /// `dayIndex` counts the days from the first day of use after analytics became active. It is not the install day.
    static func dailyUsage(dayIndex: Int, _ day: UsageDay) -> AnalyticsEvent {
        var properties: [String: Value] = [
            "day_index": .count(min(max(dayIndex, 0), 3650)),
            // "0": only a background action ran, for example the "Taken" action of a reminder.
            "app_opens": .text(bucket(day.opens, ["0": 0...0, "1": 1...1, "2_3": 2...3, "4_6": 4...6], over: "7_plus")),
        ]
        for flag in UsageFlag.allCases {
            properties[flag.rawValue] = .flag(day.used.contains(flag))
        }
        if let items = day.activeItems {
            properties["active_items"] = .text(bucket(items, ["0": 0...0, "1": 1...1, "2_3": 2...3, "4_6": 4...6], over: "7_plus"))
        }
        if let hasWidget = day.hasWidget { properties["has_widget"] = .flag(hasWidget) }
        // Only a bucket. No name, no ID, no kind, and no count of pets (spec 10, D121).
        if let size = day.familySize { properties["family_size"] = .text(bucket(size, ["1": 0...1, "2": 2...2], over: "3_plus")) }
        return AnalyticsEvent(unchecked: "daily_usage_summary", properties)
    }

    static func coreError(_ operation: Operation, _ code: ErrorCode, rule: StoredDataRule? = nil) -> AnalyticsEvent {
        var properties: [String: Value] = ["operation": .text(operation.rawValue), "code": .text(code.rawValue)]
        if let rule { properties["rule"] = .text(rule.rawValue) }
        return AnalyticsEvent(unchecked: "core_error", properties)
    }

    /// The permission that the app read differs from the one that it sent last. `previous` is `nil` for the first read.
    static func notificationPermission(_ state: Permission, previous: Permission?) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "notification_permission", [
            "state": .text(state.rawValue),
            "previous": .text(previous?.rawValue ?? "unknown"),
        ])
    }

    static func showNamesChanged(_ showsNames: Bool) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setting_changed", ["show_names": .flag(showsNames)])
    }

    static func appColorChanged(_ color: ItemColor) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setting_changed", ["app_color": .text(color.rawValue)])
    }

    /// The user set "Alarm" for every item in Settings (D085). It holds no item.
    static func allAlarmChanged(_ isOn: Bool) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setting_changed", ["all_alarm": .flag(isOn)])
    }

    /// The user set "Remind Again" for every item in Settings (D085). `nil` is off.
    static func allRemindAgainChanged(_ count: FollowUpCount?) -> AnalyticsEvent {
        let text = switch count {
        case nil: "off"
        case .untilRecorded?: "until_recorded"
        case let count?: String(count.rawValue)
        }
        return AnalyticsEvent(unchecked: "setting_changed", ["all_remind_again": .text(text)])
    }

    static func allRemindAgainIntervalChanged(_ interval: FollowUpInterval) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "setting_changed", ["all_remind_again_minutes": .text(String(interval.rawValue))])
    }

    static func dataAction(_ action: DataAction, _ result: DataResult) -> AnalyticsEvent {
        AnalyticsEvent(unchecked: "data_action", ["action": .text(action.rawValue), "result": .text(result.rawValue)])
    }

    static var feedbackOpened: AnalyticsEvent {
        AnalyticsEvent(unchecked: "feedback_entry", ["entry": .text("settings")])
    }

    private static func durationBucket(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<30: "under_30s"
        case ..<120: "30s_to_2m"
        case ..<300: "2m_to_5m"
        default: "over_5m"
        }
    }

    private static func bucket(_ value: Int, _ buckets: KeyValuePairs<String, ClosedRange<Int>>, over: String) -> String {
        buckets.first { $0.value.contains(value) }?.key ?? over
    }
}
