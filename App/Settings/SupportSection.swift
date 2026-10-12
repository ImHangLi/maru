import SwiftUI

/// "Support Maru": three optional tips (spec 14 C). Nothing in Maru depends on a tip.
/// The section calls `SupportStore`, and the store is the only code that talks to StoreKit.
struct SupportSection: View {
    private let store = SupportStore.shared

    var body: some View {
        Section {
            ForEach(store.products) { product in
                Button {
                    Task { await store.buy(product) }
                } label: {
                    LabeledContent(product.displayName) {
                        Text(product.displayPrice)
                    }
                }
                .disabled(store.buyingID != nil)
            }
        } header: {
            Text("Support Maru")
        } footer: {
            Text(footerText)
        }
        .task { await store.loadProducts() }
    }

    private var footerText: LocalizedStringKey {
        switch store.notice {
        case .thanks: "Thank you for your support."
        case .pending: "Your tip waits for approval."
        case .failed: "The tip did not go through."
        case nil:
            if store.products.isEmpty, !store.isLoading {
                "Tips are not available now."
            } else {
                "A tip is optional and unlocks nothing."
            }
        }
    }
}
