import SwiftUI

/// The paywall of Maru Pro (D107, D115): the app icon and "Maru Pro", three benefits with a symbol, two plans, the terms
/// in one line, the buy button, and "Continue Free" with the same size and shape. System fonts, system colors, and
/// system buttons only. No countdown, no trial switch, and no discount.
///
/// It is a custom view, because `SubscriptionStoreView` shows one subscription group and cannot sell the lifetime
/// plan beside it (D115). The prices come from StoreKit through `ProStore`. The view never reads or writes health data.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var plan = ProPlan.yearly
    @State private var notice: Notice?
    @State private var showsRedeem = false
    @State private var isRestoring = false
    @State private var isWelcoming = false
    @State private var bounce = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Notice: Equatable {
        case pending, failed, restored, nothingToRestore
    }

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyURL = URL(string: "https://maru.day/privacy/")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    benefits
                    plans
                    VStack(spacing: 12) {
                        if let notice {
                            noticeText(notice)
                                .font(.subheadline)
                        } else if let terms {
                            terms.font(.footnote).foregroundStyle(.secondary)
                        }
                        buttons
                    }
                    links
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color(.systemGroupedBackground))
            .overlay { if isWelcoming { welcome } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await model.loadProOffers() }
        // When only the other plan loaded, select it, so the buy button sells the plan whose row shows.
        .onChange(of: model.pro.offers) { _, offers in
            if offers[plan] == nil, let loaded = ProPlan.allCases.first(where: { offers[$0] != nil }) { plan = loaded }
        }
        .redeemCodeSheet(isPresented: $showsRedeem)
        // A purchase that ends outside the paywall, for example an approved request, closes it too.
        .onChange(of: model.pro.isPro) { _, isPro in
            if isPro { finish() }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            AppIconPreview(icon: model.settings.appIcon, size: 64)
                .accessibilityHidden(true)
            Text("Maru Pro")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Three symbols with a short label. The symbol says the same as the label to a reader of another language.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            Benefit(symbol: "lock.iphone", title: "Dose on Lock Screen")
            Divider().padding(.leading, 56)
            Benefit(symbol: "applewatch", title: "Apple Watch")
            Divider().padding(.leading, 56)
            Benefit(symbol: "paintpalette", title: "Colors, Icons, Sounds")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard()
    }

    /// The thank-you after a purchase. It shows for a moment, and then the paywall closes.
    private var welcome: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: bounce)
            Text("Welcome to Maru Pro")
                .font(.title.bold())
            Text("Thank you. Your extras are ready.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .sensoryFeedback(.success, trigger: isWelcoming)
        .onAppear { if !reduceMotion { bounce = true } }
    }

    /// Closes the paywall after a purchase, with a short thank-you. A second call does nothing.
    private func finish() {
        guard !isWelcoming else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { isWelcoming = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
        }
    }

    /// Each plan that loaded has its own row, so a plan never sells without its price on the display (App Review 3.1.2).
    @ViewBuilder
    private var plans: some View {
        if !model.pro.offers.isEmpty {
            VStack(spacing: 0) {
                if let yearly = offer(.yearly) {
                    PlanRow(
                        title: "Yearly",
                        note: yearly.trialDays.map { Text("\($0) days free") },
                        price: yearly.displayPrice,
                        period: "per year",
                        isSelected: plan == .yearly
                    ) { plan = .yearly }
                }
                if offer(.yearly) != nil, offer(.lifetime) != nil { Divider().padding(.leading, 56) }
                if let lifetime = offer(.lifetime) {
                    PlanRow(
                        title: "Lifetime",
                        note: Text("No subscription"),
                        price: lifetime.displayPrice,
                        period: "one time",
                        isSelected: plan == .lifetime
                    ) { plan = .lifetime }
                }
            }
            .groupedCard()
        } else if model.pro.isLoading {
            ProgressView()
                .frame(minHeight: 100)
        } else {
            VStack(spacing: 12) {
                Text("Prices didn’t load. Check your connection and try again.")
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await model.loadProOffers() } }
            }
            .frame(minHeight: 100)
        }
    }

    /// The terms of the selected plan, in one line under the plans, with its price and its period (App Review 3.1.2).
    private var terms: Text? {
        guard let selected = offer(plan) else { return nil }
        let price = selected.displayPrice
        return switch plan {
        case .yearly:
            if let days = selected.trialDays {
                Text("Free for \(days) days, then \(price) per year. Renews until you cancel.")
            } else {
                Text("\(price) per year. Renews until you cancel.")
            }
        case .lifetime:
            Text("One payment. It does not renew.")
        }
    }

    /// The buy button and "Continue Free" have the same size, shape, and font, so neither looks like the only way on.
    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                buy()
            } label: {
                Group {
                    if model.pro.buying != nil {
                        ProgressView()
                    } else {
                        buyTitle
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            // A plan whose product and price did not load has no row, so it can not be bought.
            .disabled(offer(plan) == nil || model.pro.buying != nil || isRestoring)
            Button {
                dismiss()
            } label: {
                Text("Continue Free")
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(.systemGray5))
        }
        .controlSize(.large)
        .font(.headline)
    }

    private var buyTitle: Text {
        switch plan {
        case .yearly: offer(.yearly)?.trialDays == nil ? Text("Subscribe Yearly") : Text("Try It Free")
        case .lifetime: Text("Buy Lifetime")
        }
    }

    private var links: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Button("Restore Purchases") { restore() }
                    .disabled(isRestoring || model.pro.buying != nil)
                Button("Redeem Code") { showsRedeem = true }
            }
            HStack(spacing: 20) {
                if let url = Self.termsURL { Link("Terms of Use", destination: url) }
                if let url = Self.privacyURL { Link("Privacy Policy", destination: url) }
            }
        }
        .font(.footnote)
    }

    @ViewBuilder
    private func noticeText(_ notice: Notice) -> some View {
        switch notice {
        case .pending: Text("Your purchase is waiting for approval. Pro turns on when it’s approved.")
        case .failed: Text("The purchase didn’t go through. Please try again.")
        case .restored: Text("Maru Pro is back. Thank you.")
        case .nothingToRestore: Text("No Maru Pro purchase was found for this Apple Account.")
        }
    }

    private func offer(_ plan: ProPlan) -> ProOffer? {
        model.pro.offers[plan]
    }

    private func buy() {
        notice = nil
        Task {
            switch await model.buyPro(plan) {
            case .purchased?: finish()
            case .pending?: notice = .pending
            case .failed?: notice = .failed
            // A cancel leaves the paywall as it was, with no other offer.
            case .cancelled?, .restored?, nil: break
            }
        }
    }

    private func restore() {
        notice = nil
        isRestoring = true
        Task {
            switch await model.restorePro() {
            case .restored?: notice = .restored
            case nil: notice = .nothingToRestore
            case .failed?: notice = .failed
            case .cancelled?, .purchased?, .pending?: break
            }
            isRestoring = false
        }
    }
}

private struct Benefit: View {
    let symbol: String
    let title: LocalizedStringKey
    @ScaledMetric(relativeTo: .title3) private var symbolWidth = 28

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: symbolWidth)
                .accessibilityHidden(true)
            Text(title).font(.body).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

/// One plan as a row of a grouped list, with a check circle as the Settings app has. The price is the largest text of
/// the row, larger than the trial words (App Review 3.1.2).
private struct PlanRow: View {
    let title: LocalizedStringKey
    let note: Text?
    let price: String
    let period: LocalizedStringKey
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title3) private var symbolWidth = 28

    var body: some View {
        // At an accessibility text size, the price goes under the name, so no word breaks.
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        Button(action: select) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .frame(width: symbolWidth)
                    .accessibilityHidden(true)
                layout {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        if let note { note.font(.subheadline).foregroundStyle(.secondary) }
                    }
                    if !stacked { Spacer(minLength: 8) }
                    VStack(alignment: stacked ? .leading : .trailing, spacing: 2) {
                        Text(verbatim: price).font(.headline)
                        Text(period).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if stacked { Spacer(minLength: 0) }
            }
            .multilineTextAlignment(.leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension View {
    /// A grouped card as in a Settings list: the secondary grouped background and a continuous corner.
    func groupedCard() -> some View {
        background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    /// Shows the paywall of the model on this view. The root view hosts it, and a sheet such as Settings hosts it while
    /// it is up, because one view shows one sheet at a time.
    func paywallHost(_ isActive: Bool) -> some View {
        modifier(PaywallHost(isActive: isActive))
    }
}

private struct PaywallHost: ViewModifier {
    @Environment(AppModel.self) private var model
    let isActive: Bool

    func body(content: Content) -> some View {
        content.sheet(item: Binding(
            get: { isActive ? model.proState.paywall : nil },
            set: { if $0 == nil, isActive { model.paywallDidClose() } }
        )) { _ in
            #if DEBUG
            if DebugLaunch.wantsPaywallStyleB { PaywallStyleB() } else { PaywallView() }
            #else
            PaywallView()
            #endif
        }
    }
}
