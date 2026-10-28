import Foundation
import MaruCore
import MaruDatabase

/// The next dose of the first item, for the Lock Screen preview of the first-value offer (D107). It stays in memory
/// and on the display. Nothing of it leaves the device.
struct NextDosePreview: Equatable {
    let name: String
    let form: ItemForm
    let color: ItemColor
    let imageReference: String?
    let amount: String?
    /// The next reminder time of the plan, as the user's region writes it.
    let time: String
}

/// One showing of the paywall.
struct PaywallRequest: Identifiable, Equatable {
    let id = UUID()
    let source: AnalyticsEvent.PaywallSource
    /// Only the first-value offer has it.
    let preview: NextDosePreview?
}

/// The state of Maru Pro that is not in StoreKit (D107). The flags of the offers are in `UserDefaults.standard`, as
/// the onboarding flag (D103). They hold no item data, and a backup does not carry them.
struct ProState {
    /// The paywall on the display.
    var paywall: PaywallRequest?
    /// The first-value offer waits for the alerts and the questions after a save.
    var firstValueOffer: NextDosePreview?
    /// At least 5 doses have a record. The card of Today needs it. It is read once in a process, until it is true.
    var hasEnoughRecords = false
    var isReadingRecords = false
    /// "×" on the card of Today.
    var cardDismissed = UserDefaults.standard.bool(forKey: ProOffers.cardDismissedKey)
}

/// The keys and the limits of the two offers that Maru shows by itself (D107).
enum ProOffers {
    static let firstValueShownKey = "pro.firstValueShown"
    static let cardDismissedKey = "pro.cardDismissed"
    /// The days on which the card of Today showed, at most `cardDayLimit`.
    static let cardDaysKey = "pro.cardDays"
    static let cardDayLimit = 3
    static let cardFirstDays: TimeInterval = 7 * 24 * 60 * 60
    static let cardRecords = 5
}

extension AppStore {
    func hasRecords(atLeast count: Int) async throws(StorageError) -> Bool {
        try await open().hasRecords(atLeast: count)
    }
}

extension AppModel {
    var pro: ProStore { .shared }

    /// The one entry to the paywall (D107). A Pro feature calls it with `.feature` when a free user taps it. Each
    /// showing sends `paywall_shown` with the source and nothing else.
    func presentPaywall(reason: AnalyticsEvent.PaywallSource, preview: NextDosePreview? = nil) {
        guard proState.paywall == nil, !pro.isPro else { return }
        proState.paywall = PaywallRequest(source: reason, preview: preview)
        analytics.capture(.paywallShown(reason))
    }

    func paywallDidClose() {
        proState.paywall = nil
    }

    func loadProOffers() async {
        await pro.loadOffers()
    }

    /// A purchase from the paywall. A cancel returns the user to the paywall with no other screen.
    func buyPro(_ plan: ProPlan) async -> AnalyticsEvent.PurchaseResult? {
        let result = await pro.buy(plan)
        if let result { analytics.capture(.purchaseResult(result, plan: plan.analytics)) }
        return result
    }

    /// "Restore Purchases". `nil` when the App Store has no Pro purchase for this Apple Account.
    func restorePro() async -> AnalyticsEvent.PurchaseResult? {
        let result = await pro.restore()
        if let result { analytics.capture(.purchaseResult(result, plan: pro.plan?.analytics)) }
        return result
    }

    // MARK: First-value offer

    /// The first save of a new item with a time offers Maru Pro once per install, with the user's own next dose. The
    /// save already waited for the notification permission alert. The root view shows the offer after the edit screen,
    /// the alerts, and the questions of the save.
    ///
    /// Not after a launch from a reminder or a widget in this process. Then the flag stays unset, and the next such save
    /// offers it.
    func offerFirstValue(for item: Item, schedule: Schedule?, session: EditorSession, at now: Date) {
        guard session.isNew, session.replaced == nil, let schedule, schedule.isEnabled,
              let version = schedule.versions.last, !opensForAction, !pro.isPro, pro.canMakePayments,
              !UserDefaults.standard.bool(forKey: ProOffers.firstValueShownKey) else { return }
        // A plain clock time of the device. The preview shows a time and no date, so a plan that skips today shows its
        // first time.
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let times = version.slotTimes.map(\.time).sorted()
        let clock = try? WallClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
        guard let next = times.first(where: { time in clock.map { time > $0 } ?? false }) ?? times.first else { return }
        proState.firstValueOffer = NextDosePreview(
            name: item.name,
            form: item.form,
            color: item.color,
            imageReference: item.imageReference,
            amount: version.dose?.text,
            time: SchedulePreview.format(hour: next.hour, minute: next.minute)
        )
    }

    /// The root view shows the offer now. It never shows again on this device.
    func showFirstValueOffer() {
        guard let preview = proState.firstValueOffer else { return }
        proState.firstValueOffer = nil
        UserDefaults.standard.set(true, forKey: ProOffers.firstValueShownKey)
        presentPaywall(reason: .firstValue, preview: preview)
    }

    // MARK: Card of Today

    /// The card at the bottom of Today: never modal, at least 7 days after the first launch, at least 5 records, not on
    /// a day of the rating prompt, not while a dose is due, on at most 3 days, and never after "×" (D107).
    func showsProCard(_ day: TodaySnapshot, at now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        guard proState.hasEnoughRecords, !proState.cardDismissed, !pro.isPro, pro.canMakePayments,
              let firstLaunch = ReviewPrompt.firstLaunch(), now.timeIntervalSince(firstLaunch) >= ProOffers.cardFirstDays,
              !ReviewPrompt.askedToday(now: now) else { return false }
        let days = defaults.stringArray(forKey: ProOffers.cardDaysKey) ?? []
        guard days.count < ProOffers.cardDayLimit || days.contains(Self.dayKey(day.date)) else { return false }
        // A planned dose whose time came and that has no record is due. The card waits until it has one.
        return !day.entries.contains { entry in
            !isDone(entry) && entry.occurrence.timeZone.resolve(entry.occurrence.plannedTime, on: entry.occurrence.plannedDate)
                .earliestInstant <= now
        }
    }

    /// Reads the count of records once, when the other rules of the card can pass. A failed read shows no card.
    func readProCardRecords() {
        guard !proState.hasEnoughRecords, !proState.isReadingRecords, !proState.cardDismissed, !pro.isPro,
              let firstLaunch = ReviewPrompt.firstLaunch(), Date().timeIntervalSince(firstLaunch) >= ProOffers.cardFirstDays
        else { return }
        proState.isReadingRecords = true
        Task {
            let enough = (try? await store.hasRecords(atLeast: ProOffers.cardRecords)) ?? false
            proState.isReadingRecords = false
            if enough { proState.hasEnoughRecords = true }
        }
    }

    /// The card is on Today on this day. Each day counts once.
    func proCardDidShow(on date: LocalDate) {
        let defaults = UserDefaults.standard
        var days = defaults.stringArray(forKey: ProOffers.cardDaysKey) ?? []
        let key = Self.dayKey(date)
        guard !days.contains(key), days.count < ProOffers.cardDayLimit else { return }
        days.append(key)
        defaults.set(days, forKey: ProOffers.cardDaysKey)
    }

    /// "×" on the card. It never shows again on this device.
    func dismissProCard() {
        proState.cardDismissed = true
        UserDefaults.standard.set(true, forKey: ProOffers.cardDismissedKey)
    }

    private static func dayKey(_ date: LocalDate) -> String {
        String(format: "%04d-%02d-%02d", date.year, date.month, date.day)
    }
}
