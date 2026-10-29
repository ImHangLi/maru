import Foundation
import MaruCore
import MaruDatabase

/// One showing of the paywall.
struct PaywallRequest: Identifiable, Equatable {
    let id = UUID()
    let source: AnalyticsEvent.PaywallSource
}

/// The state of Maru Pro that is not in StoreKit (D107). The flags of the offers are in `UserDefaults.standard`, as
/// the onboarding flag (D103). They hold no item data, and a backup does not carry them.
struct ProState {
    /// The paywall on the display.
    var paywall: PaywallRequest?
    /// The first-value offer waits for the alerts and the questions after a save.
    var firstValueOffer = false
    /// At least 5 doses have a record. The card of Today needs it. It is read until it is true, and again after an
    /// undo, a delete, or a restore.
    var hasEnoughRecords = false
    var isReadingRecords = false
    /// Goes up when the count is out of date, so a read that started before gives no result.
    var recordsRead = 0
    /// Goes up at the planned time of the next open dose of Today, so Today reads the rules of the card again.
    var cardClock = 0
    var cardCheck: Task<Void, Never>?
    /// "×" on the card of Today.
    var cardDismissed = UserDefaults.standard.bool(forKey: ProOffers.cardDismissedKey)
    /// A free user tapped "Open on iPhone" on the Watch (D111). The request can start Maru in the background, so it waits
    /// in `UserDefaults.standard` until Maru is in front.
    var watchAsked = UserDefaults.standard.bool(forKey: ProOffers.watchAskedKey)
}

/// The keys and the limits of the two offers that Maru shows by itself (D107).
enum ProOffers {
    static let firstValueShownKey = "pro.firstValueShown"
    static let cardDismissedKey = "pro.cardDismissed"
    static let watchAskedKey = "pro.watchAsked"
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

    /// The one entry to the paywall (D107). A Pro feature calls it with its own source when a free user taps it. Each
    /// showing sends `paywall_shown` with the source and nothing else.
    func presentPaywall(reason: AnalyticsEvent.PaywallSource) {
        guard proState.paywall == nil, !pro.isPro else { return }
        proState.paywall = PaywallRequest(source: reason)
        analytics.capture(.paywallShown(reason))
    }

    /// A close with no active Pro sends `dismissed`, so each showing has an end that counts (D127). A close after a purchase
    /// or a restore sends nothing more.
    func paywallDidClose() {
        proState.paywall = nil
        if !pro.isPro { analytics.capture(.purchaseResult(.dismissed, plan: nil)) }
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

    // MARK: Watch

    /// The locked screen of the Watch app asked for Maru Pro (D111). The root view shows the paywall the next time that
    /// Maru is in front, after the onboarding, the edit screen, and the alerts.
    func watchAskedForPro() {
        // A paywall that is open already answers the request, so its close does not open a second one.
        guard !pro.isPro, proState.paywall == nil else { return }
        proState.watchAsked = true
        UserDefaults.standard.set(true, forKey: ProOffers.watchAskedKey)
    }

    /// The root view shows the paywall that the Watch asked for. It shows one time for each request.
    func showWatchOffer() {
        guard proState.watchAsked else { return }
        proState.watchAsked = false
        UserDefaults.standard.removeObject(forKey: ProOffers.watchAskedKey)
        presentPaywall(reason: .watch)
    }

    // MARK: First-value offer

    /// The first save of a new item with a time offers Maru Pro once per install. The save already waited for the
    /// notification permission alert. The root view shows the offer after the edit screen, the alerts, and the
    /// questions of the save.
    ///
    /// Not after a launch from a reminder or a widget in this process. Then the flag stays unset, and the next such save
    /// offers it.
    func offerFirstValue(schedule: Schedule?, session: EditorSession) {
        guard session.isNew, session.replaced == nil, let schedule, schedule.isEnabled,
              schedule.versions.last?.slotTimes.isEmpty == false, !opensForAction, !pro.isPro, pro.canMakePayments,
              !UserDefaults.standard.bool(forKey: ProOffers.firstValueShownKey) else { return }
        proState.firstValueOffer = true
    }

    /// The root view shows the offer now. It never shows again on this device.
    func showFirstValueOffer() {
        guard proState.firstValueOffer else { return }
        proState.firstValueOffer = false
        UserDefaults.standard.set(true, forKey: ProOffers.firstValueShownKey)
        presentPaywall(reason: .firstValue)
    }

    // MARK: Card of Today

    /// The card at the bottom of Today: never modal, at least 7 days after the first launch, at least 5 records, not on
    /// a day of the rating prompt, not while a dose is due, on at most 3 days, and never after "×" (D107).
    func showsProCard(_ day: TodaySnapshot, at now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        // Today shows the card again when the clock goes up.
        _ = proState.cardClock
        guard proState.hasEnoughRecords, !proState.cardDismissed, !pro.isPro, pro.canMakePayments,
              let firstLaunch = ReviewPrompt.firstLaunch(), now.timeIntervalSince(firstLaunch) >= ProOffers.cardFirstDays,
              !ReviewPrompt.askedToday(now: now) else { return false }
        let days = defaults.stringArray(forKey: ProOffers.cardDaysKey) ?? []
        guard days.count < ProOffers.cardDayLimit || days.contains(Self.dayKey(day.date)) else { return false }
        // A planned dose whose time came and that has no record is due. The card waits until it has one.
        return !day.entries.contains { entry in
            !isDone(entry) && Self.plannedInstant(entry) <= now
        }
    }

    /// The card hides when a dose becomes due. So Today reads the rules again at the planned time of the next open
    /// dose. Each new content of Today and each commit set the check again. A return to the front reads Today again.
    func scheduleProCardCheck(for day: TodaySnapshot, at now: Date = Date()) {
        proState.cardCheck?.cancel()
        proState.cardCheck = nil
        guard !proState.cardDismissed, !pro.isPro,
              let next = day.entries.filter({ !isDone($0) }).map(Self.plannedInstant).filter({ $0 > now }).min()
        else { return }
        proState.cardCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(next.timeIntervalSinceNow + 1, 1)))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            proState.cardClock += 1
            if case let .loaded(snapshot) = content, let day = snapshot.today { scheduleProCardCheck(for: day) }
        }
    }

    /// The planned time of a dose of Today, as an instant. The Live Activity uses it too (D110).
    static func plannedInstant(_ entry: TodaySnapshot.Entry) -> Date {
        entry.occurrence.timeZone.resolve(entry.occurrence.plannedTime, on: entry.occurrence.plannedDate).earliestInstant
    }

    /// Reads the count of records, when the other rules of the card can pass. A failed read shows no card.
    func readProCardRecords() {
        guard !proState.hasEnoughRecords, !proState.isReadingRecords, !proState.cardDismissed, !pro.isPro,
              let firstLaunch = ReviewPrompt.firstLaunch(), Date().timeIntervalSince(firstLaunch) >= ProOffers.cardFirstDays
        else { return }
        proState.isReadingRecords = true
        let generation = dataGeneration
        let read = proState.recordsRead
        Task {
            let enough = (try? await store.hasRecords(atLeast: ProOffers.cardRecords)) ?? false
            // A restore, an undo, or a delete after the read started can make the count wrong.
            guard generation == dataGeneration, read == proState.recordsRead else { return }
            proState.isReadingRecords = false
            if enough { proState.hasEnoughRecords = true }
        }
    }

    /// An undo removes the record of a dose.
    func proRecordsDidCommit(_ records: [OccurrenceRecord]) {
        if records.contains(where: { $0.events.last?.action == .undo }) { proRecordsDidChange() }
    }

    /// An undo, a delete, or a restore can remove records. The count is read again, and a read that runs gives no result.
    func proRecordsDidChange() {
        proState.recordsRead += 1
        proState.hasEnoughRecords = false
        proState.isReadingRecords = false
        readProCardRecords()
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
