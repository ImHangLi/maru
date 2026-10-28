import Observation
import StoreKit

/// The optional tips (spec 14 C, T35, T48). A tip unlocks nothing and never touches health data.
/// This service is the only code that buys with StoreKit. It keeps no purchase state on disk:
/// a consumable tip has no entitlement, so there is nothing to restore.
@MainActor
@Observable
final class SupportStore {
    static let shared = SupportStore()

    /// The prices are set in App Store Connect. Maru shows `displayPrice` and has no price in code.
    static let productIDs = [
        "com.imhangli.maru.tip.small",
        "com.imhangli.maru.tip.medium",
        "com.imhangli.maru.tip.large",
    ]

    /// What the user sees after a tip. A cancel and a refund have no notice.
    enum Notice: Equatable {
        case thanks
        case pending
        case failed
    }

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var buyingID: String?
    private(set) var notice: Notice?

    @ObservationIgnored private var listener: Task<Void, Never>?

    /// Starts the listener for transactions that end outside a purchase call: a tip that was
    /// pending, an interrupted tip, and a refund. The task waits for the system and blocks nothing (T35).
    func startListening() {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if await self.settle(result) == .thanks { self.notice = .thanks }
            }
        }
    }

    /// Loads the tips when the section shows. A failure leaves the list empty, and the app as it is.
    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
    }

    func buy(_ product: Product) async {
        guard buyingID == nil else { return }
        buyingID = product.id
        notice = nil
        defer { buyingID = nil }
        do {
            switch try await product.purchase() {
            case let .success(result): notice = await settle(result)
            case .pending: notice = .pending
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            notice = .failed
        }
    }

    /// Finishes the transaction, so StoreKit does not deliver it again. Returns `.thanks` for a tip that
    /// the system verified. A refund has no notice. An unverified transaction counts as a failure.
    private func settle(_ result: VerificationResult<Transaction>) async -> Notice? {
        switch result {
        case let .verified(transaction):
            await transaction.finish()
            return transaction.revocationDate == nil ? .thanks : nil
        case let .unverified(transaction, _):
            await transaction.finish()
            return .failed
        }
    }
}
