import SwiftUI

/// The second paywall of Maru Pro (D116, "style B"), an option next to the plain one of D115. One gradient picture is the
/// focal point, with one headline that names the outcome. Under it come three tiles for the paid features, the plans,
/// the terms of the selected plan, and the buy button that names the plan. System fonts and system buttons only.
///
/// It uses the same StoreKit calls as `PaywallView` and changes no price rule, trial rule, or entitlement rule (D107).
/// The picture is `ProHero` in the asset catalog. Codex made it, and `docs/third-party-licenses.md` records it. It drifts
/// slowly, and it stands still with Reduce Motion. When the maintainer keeps one style, delete the other file.
struct PaywallStyleB: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var plan = ProPlan.yearly
    @State private var notice: Notice?
    @State private var showsRedeem = false
    @State private var isRestoring = false
    @State private var isWelcoming = false
    @State private var bounce = false

    private enum Notice: Equatable {
        case pending, failed, restored, nothingToRestore
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero(minHeight: min(max(proxy.size.height * 0.34, 220), 320))
                    VStack(spacing: 16) {
                        benefits
                        plans
                        VStack(spacing: 12) {
                            if let notice {
                                noticeText(notice).font(.subheadline)
                            } else if let terms {
                                terms.font(.footnote).foregroundStyle(.secondary)
                            }
                            buttons
                        }
                        links
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 560)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
        }
        .background(Color(.systemBackground))
        // The close button stays in view when the page scrolls.
        .overlay(alignment: .topTrailing) { closeButton }
        .overlay { if isWelcoming { welcome } }
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

    // MARK: Hero

    /// The picture, with the name, the headline, and one supporting line over a dark scrim at its foot. The text is white
    /// in light and dark mode, because the picture does not change with the mode.
    private func hero(minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Text("Maru Pro")
                .font(.subheadline.weight(.semibold))
                .opacity(0.85)
            Text("Your next dose, at a glance.")
                // At an accessibility text size the picture would fill the whole screen, so the lines are one step smaller.
                .font(typeSize.isAccessibilitySize ? .title2.bold() : .largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("Add Lock Screen, Apple Watch, and your own look. Reminders stay free.")
                .font(typeSize.isAccessibilitySize ? .callout : .body)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        // The top padding keeps the text clear of the close button at a large text size.
        .padding(.top, 56)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomLeading)
        .background {
            ZStack {
                HeroArt(isStill: reduceMotion)
                LinearGradient(
                    stops: [.init(color: .black.opacity(0), location: 0.3), .init(color: .black.opacity(0.5), location: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .accessibilityHidden(true)
        }
        .clipShape(.rect(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.28), in: .circle)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel("Close")
        .padding(.top, 8)
        .padding(.trailing, 8)
    }

    // MARK: Benefits

    /// Three tiles, each a symbol in the tint with two to four words. At an accessibility text size they become rows.
    private var benefits: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
        return layout {
            BenefitTile(symbol: "lock.iphone", title: "Dose on Lock Screen")
            BenefitTile(symbol: "applewatch", title: "Apple Watch")
            BenefitTile(symbol: "paintpalette", title: "Colors, Icons, Sounds")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Plans

    /// Each plan that loaded has its own card, so a plan never sells without its price on the display (App Review 3.1.2).
    @ViewBuilder
    private var plans: some View {
        if !model.pro.offers.isEmpty {
            VStack(spacing: 10) {
                if let yearly = offer(.yearly) {
                    PlanCard(
                        title: "Yearly",
                        note: yearly.trialDays.map { Text("\($0) days free") },
                        price: yearly.displayPrice,
                        period: "per year",
                        isSelected: plan == .yearly
                    ) { plan = .yearly }
                }
                if let lifetime = offer(.lifetime) {
                    PlanCard(
                        title: "Lifetime",
                        note: Text("No subscription"),
                        price: lifetime.displayPrice,
                        period: "one time",
                        isSelected: plan == .lifetime
                    ) { plan = .lifetime }
                }
            }
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

    /// The terms of the selected plan, directly above the button, with its price, its period, and how it ends.
    private var terms: Text? {
        guard let selected = offer(plan) else { return nil }
        let price = selected.displayPrice
        return switch plan {
        case .yearly:
            if let days = selected.trialDays {
                Text("Free for \(days) days, then \(price) per year. Renews automatically. Cancel anytime.")
            } else {
                Text("\(price) per year. Renews automatically. Cancel anytime.")
            }
        case .lifetime:
            Text("One payment. It does not renew.")
        }
    }

    // MARK: Buttons

    /// The buy button names the selected plan. "Continue Free" has the same size, font, and shape, so neither looks like
    /// the only way on.
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
            // A plan whose product and price did not load has no card, so it can not be bought.
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
        case .yearly: offer(.yearly)?.trialDays == nil ? Text("Subscribe Yearly") : Text("Start Free Trial")
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
                if let url = PaywallView.termsURL { Link("Terms of Use", destination: url) }
                if let url = PaywallView.privacyURL { Link("Privacy Policy", destination: url) }
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

    // MARK: Thank-you and actions

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
        .background(Color(.systemBackground))
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

/// The gradient picture. It drifts slowly and stops with Reduce Motion.
private struct HeroArt: View {
    let isStill: Bool
    @State private var drifts = false

    var body: some View {
        GeometryReader { proxy in
            Image("ProHero")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(1.15)
                .offset(x: drifts ? -12 : 12, y: drifts ? 8 : -8)
                .clipped()
        }
        .onAppear { updateDrift() }
        .onChange(of: isStill) { _, _ in updateDrift() }
    }

    private func updateDrift() {
        if isStill {
            withAnimation(.easeOut(duration: 0.2)) { drifts = false }
        } else {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { drifts = true }
        }
    }
}

/// One paid feature: a symbol in the tint on a rounded square, and two to four words under it.
private struct BenefitTile: View {
    let symbol: String
    let title: LocalizedStringKey
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var chip = 44

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(HStackLayout(spacing: 14))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: chip, height: chip)
                .background(.tint, in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            Text(title)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
            if typeSize.isAccessibilitySize { Spacer(minLength: 0) }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        // The tiles of a row have the height of the tallest one.
        .frame(maxWidth: .infinity, maxHeight: typeSize.isAccessibilitySize ? nil : .infinity, alignment: .top)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// One plan as a card with a check circle. The selected card has a border in the tint. The price is as large as the name
/// and larger than the note (App Review 3.1.2).
private struct PlanCard: View {
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
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
