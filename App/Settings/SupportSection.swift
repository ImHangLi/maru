import SwiftUI

/// "Support Maru": three optional tips (spec 14 C). Nothing in Maru depends on a tip.
/// The section calls `SupportStore`, and the store is the only code that talks to StoreKit.
struct SupportSection: View {
    private let store = SupportStore.shared

    var body: some View {
        // Without products the section has nothing to offer, so it does not show. SettingsView loads the products.
        if !store.products.isEmpty {
            Section {
                ForEach(store.products) { product in
                    Button {
                        Task { await store.buy(product) }
                    } label: {
                        LabeledContent(product.displayName) {
                            Text(product.displayPrice)
                        }
                    }
                    .rowText()
                    .disabled(store.buyingID != nil)
                }
            } header: {
                Text("Support Maru")
            } footer: {
                Text(footerText)
            }
        }
    }

    private var footerText: LocalizedStringKey {
        switch store.notice {
        case .thanks: "Thank you for your support."
        case .pending: "Your tip waits for approval."
        case .failed: "The tip did not go through."
        case nil: "A tip is optional and unlocks nothing."
        }
    }
}
