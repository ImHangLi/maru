import Foundation
import MaruCore
import Observation
import StoreKit
import SwiftUI

/// The two plans of Maru Pro (D107). The prices, the trial, and Family Sharing are set in App Store Connect, not in code.
enum ProPlan: String, CaseIterable, Sendable {
    case yearly, lifetime

    var productID: String {
        switch self {
        case .yearly: "com.imhangli.maru.pro.yearly"
        case .lifetime: "com.imhangli.maru.pro.lifetime"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    var analytics: AnalyticsEvent.PurchasePlan {
        switch self {
        case .yearly: .yearly
        case .lifetime: .lifetime
        }
    }
}

/// What the paywall shows for one plan, as plain values, so no view needs StoreKit.
struct ProOffer: Equatable, Sendable {
    let plan: ProPlan
    /// The price in the currency and the format of the App Store of the user.
    let displayPrice: String
    /// The days of the free trial, when this user can still get it. `nil` for the lifetime plan.
    let trialDays: Int?
}

/// Maru Pro (D107). This file is the only code that imports StoreKit. `MaruCore` and `MaruDatabase` do not.
///
/// A purchase never reads or writes health data. Every free feature works the same with and without Pro, so a failed,
/// cancelled, pending, or refunded purchase changes no free feature (T48). The launch does not wait for StoreKit (T35).
@MainActor
@Observable
final class ProStore {
    static let shared = ProStore()

    /// The last known plan, in `UserDefaults.standard` beside the display settings (D014). A Pro feature reads it at
    /// launch, so it does not flicker while StoreKit answers. StoreKit corrects it at each launch, each update, and each
    /// return to the front.
    private static let planKey = "pro.plan"
    /// The end of access of the yearly plan, with a billing grace period. A cached yearly plan after it is free.
    private static let expiresKey = "pro.expires"

    /// `nil` is free.
    private(set) var plan: ProPlan?
    private(set) var offers: [ProPlan: ProOffer] = [:]
    private(set) var isLoading = false
    /// The plan of a purchase that runs. The paywall disables its buttons while it runs.
    private(set) var buying: ProPlan?

    var isPro: Bool { plan != nil }

    @ObservationIgnored private var products: [ProPlan: Product] = [:]
    @ObservationIgnored private var listener: Task<Void, Never>?
    /// The end of access of the yearly plan. `nil` for the lifetime plan and for free.
    @ObservationIgnored private var expiresAt: Date?
    /// Reads the entitlement again at `expiresAt`, also when the process stays alive with no network.
    @ObservationIgnored private var expiryCheck: Task<Void, Never>?

    private init() {
        let defaults = UserDefaults.standard
        let plan = defaults.string(forKey: Self.planKey).flatMap(ProPlan.init(rawValue:))
        let expiresAt = defaults.object(forKey: Self.expiresKey) as? Date
        // The cache never grants a yearly plan after its end of access.
        if plan == .yearly, (expiresAt ?? .distantPast) <= Date() {
            self.plan = nil
        } else {
            self.plan = plan
            self.expiresAt = plan == .yearly ? expiresAt : nil
        }
    }

    /// `false` when Screen Time or a device profile blocks purchases. Maru then offers nothing by itself.
    var canMakePayments: Bool { StoreKit.AppStore.canMakePayments }

    /// Reads the entitlement, and listens for transactions that end outside a purchase call: a renewal, a refund, an
    /// approved purchase, a code, and a change of Family Sharing. Both tasks wait for the system, so the launch waits
    /// for nothing (T35).
    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                switch result {
                case let .verified(transaction): await transaction.finish()
                case let .unverified(transaction, _): await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        scheduleExpiryCheck()
        Task { await refreshEntitlement() }
    }

    /// Pro is active when a verified transaction for one of the two products is current and not revoked. A family
    /// member's purchase counts, because `currentEntitlements` includes shared transactions. A refund is not current,
    /// so Pro ends. The yearly plan also ends at its end of access, which this read checks itself, because the cache of
    /// StoreKit can keep an expired transaction while the device has no network.
    func refreshEntitlement() async {
        let now = Date()
        var found: ProPlan?
        var expires: Date?
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result, transaction.revocationDate == nil,
                  let plan = ProPlan(productID: transaction.productID) else { continue }
            switch plan {
            case .lifetime:
                found = .lifetime
            case .yearly:
                guard let end = await Self.endOfAccess(transaction, at: now), end > now else { continue }
                if found == nil { found = .yearly }
                expires = max(expires ?? end, end)
            }
        }
        set(found, expires: expires)
    }

    /// The expiration date of a yearly transaction, or the end of its billing grace period when StoreKit reports one.
    /// The grace period applies only after the expiration date, so the status is read only then.
    private static func endOfAccess(_ transaction: StoreKit.Transaction, at now: Date) async -> Date? {
        guard let expiration = transaction.expirationDate else { return nil }
        guard expiration <= now, let group = transaction.subscriptionGroupID,
              let statuses = try? await Product.SubscriptionInfo.status(for: group) else { return expiration }
        let grace = statuses.compactMap { status -> Date? in
            guard status.state == .inGracePeriod, case let .verified(renewal) = status.renewalInfo,
                  renewal.originalTransactionID == transaction.originalID else { return nil }
            return renewal.gracePeriodExpirationDate
        }.max()
        return max(expiration, grace ?? expiration)
    }

    /// Loads the two plans when a paywall shows. A failure leaves the offers empty, and the paywall says so.
    func loadOffers() async {
        guard offers.count < ProPlan.allCases.count, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let loaded = try? await Product.products(for: ProPlan.allCases.map(\.productID)) else { return }
        for product in loaded {
            guard let plan = ProPlan(productID: product.id) else { continue }
            products[plan] = product
            var trialDays: Int?
            if let subscription = product.subscription, let intro = subscription.introductoryOffer,
               intro.paymentMode == .freeTrial, await subscription.isEligibleForIntroOffer {
                trialDays = switch intro.period.unit {
                case .day: intro.period.value
                case .week: intro.period.value * 7
                default: nil
                }
            }
            offers[plan] = ProOffer(plan: plan, displayPrice: product.displayPrice, trialDays: trialDays)
        }
    }

    /// One purchase. `nil` when no purchase started, for example while another one runs.
    func buy(_ plan: ProPlan) async -> AnalyticsEvent.PurchaseResult? {
        guard buying == nil, let product = products[plan] else { return nil }
        buying = plan
        defer { buying = nil }
        do {
            switch try await product.purchase() {
            case let .success(.verified(transaction)):
                await transaction.finish()
                guard transaction.revocationDate == nil else { return .failed }
                if self.plan != .lifetime { set(plan, expires: transaction.expirationDate) }
                return .purchased
            case let .success(.unverified(transaction, _)):
                await transaction.finish()
                return .failed
            case .pending: return .pending
            case .userCancelled: return .cancelled
            @unknown default: return .failed
            }
        } catch {
            return .failed
        }
    }

    /// "Restore Purchases": a sync with the App Store, then a new read of the entitlement. `nil` when the sync
    /// found no Pro purchase.
    func restore() async -> AnalyticsEvent.PurchaseResult? {
        do {
            try await StoreKit.AppStore.sync()
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch {
            return .failed
        }
        await refreshEntitlement()
        return isPro ? .restored : nil
    }

    /// `expires` is the end of access of the yearly plan. The lifetime plan never expires.
    private func set(_ plan: ProPlan?, expires: Date?) {
        let expires = plan == .yearly ? expires : nil
        if plan != self.plan {
            self.plan = plan
            UserDefaults.standard.set(plan?.rawValue, forKey: Self.planKey)
        }
        expiresAt = expires
        UserDefaults.standard.set(expires, forKey: Self.expiresKey)
        scheduleExpiryCheck()
    }

    private func scheduleExpiryCheck() {
        expiryCheck?.cancel()
        guard let expiresAt else { return }
        expiryCheck = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(expiresAt.timeIntervalSinceNow + 1, 1)))
            guard !Task.isCancelled else { return }
            await self?.refreshEntitlement()
        }
    }
}

// The system sheets of StoreKit, here so that the views do not import StoreKit.
extension View {
    /// The system sheet that redeems an offer code. The transaction also comes through `Transaction.updates`.
    func redeemCodeSheet(isPresented: Binding<Bool>) -> some View {
        offerCodeRedemption(isPresented: isPresented) { _ in
            Task { @MainActor in await ProStore.shared.refreshEntitlement() }
        }
    }

    /// The system sheet that manages or cancels the yearly plan.
    func manageSubscriptionSheet(isPresented: Binding<Bool>) -> some View {
        manageSubscriptionsSheet(isPresented: isPresented)
    }

    /// The system rating prompt of D102, 1.5 seconds after each change of `trigger`, so the record circle fills and
    /// the haptic plays first. Maru shows no screen of its own before or after it.
    func reviewPrompt(trigger: Int) -> some View {
        modifier(ReviewPromptModifier(trigger: trigger))
    }
}

private struct ReviewPromptModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    let trigger: Int

    func body(content: Content) -> some View {
        content.onChange(of: trigger) {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                requestReview()
            }
        }
    }
}
