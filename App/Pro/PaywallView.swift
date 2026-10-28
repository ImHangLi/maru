import SwiftUI

/// The paywall of Maru Pro (D107, D119). It is a system sheet with a system close button in the navigation bar. A gradient
/// picture and one headline sit at the top and scroll away. The picture fades out before the benefits start, so all
/// other text sits on the plain background. Under the picture come three benefits, each with a symbol, a title, and one
/// line. The purchase area stays at the foot of the sheet while the page scrolls: two plan tiles, the terms of the
/// selected plan, one capsule button, and one line with the two legal links (App Review 3.1.2). "Restore Purchases" and
/// "Redeem Code" are in Settings (D119).
///
/// The page has one left margin, system fonts with text styles, one accent (the app tint), and the plain system
/// background. At an accessibility text size, the purchase area scrolls with the page, so it never covers the screen.
///
/// It is a custom view, because `SubscriptionStoreView` cannot sell the lifetime plan beside the yearly plan (D115). It
/// uses the StoreKit calls of `ProStore` and changes no price rule, trial rule, or entitlement rule (D107). The picture is
/// `ProHero` in the asset catalog. Codex made it, and `docs/third-party-licenses.md` records it. It drifts slowly, and it
/// stands still with Reduce Motion.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineWidth = 270
    @State private var plan = ProPlan.yearly
    @State private var notice: Notice?
    @State private var isWelcoming = false
    @State private var bounce = false

    private enum Notice: Equatable {
        case pending, failed
    }

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyURL = URL(string: "https://maru.day/privacy/")

    /// The one left and right margin of the page.
    private let margin: CGFloat = 20
    /// The height of the fade above the purchase area.
    private static let purchaseFade: CGFloat = 28
    /// The height of the fade under the picture.
    private static let heroFade: CGFloat = 96
    private var pinsPurchase: Bool { !typeSize.isAccessibilitySize }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        column { benefits }
                            .padding(.top, 16)
                            .padding(.bottom, pinsPurchase ? 16 + Self.purchaseFade : 16)
                        if pinsPurchase == false { column { purchase }.padding(.bottom, 24) }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .ignoresSafeArea(edges: .top)
                // The page fades out above the purchase area, so it scrolls away softly and no text line shows a cut.
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        if pinsPurchase {
                            LinearGradient(stops: Self.fadeStops, startPoint: .top, endPoint: .bottom)
                                .frame(height: Self.purchaseFade)
                        }
                    }
                    .ignoresSafeArea(edges: .top)
                }
                if pinsPurchase {
                    column { purchase }
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { closeButton } }
            // The picture runs under the navigation bar, so the bar has no background of its own.
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .overlay { if isWelcoming { welcome } }
        .task { await model.loadProOffers() }
        // When only the other plan loaded, select it, so the buy button sells the plan whose tile shows.
        .onChange(of: model.pro.offers) { _, offers in
            if offers[plan] == nil, let loaded = ProPlan.allCases.first(where: { offers[$0] != nil }) { plan = loaded }
        }
        // A purchase that ends outside the paywall, for example an approved request, closes it too.
        .onChange(of: model.pro.isPro) { _, isPro in
            if isPro { finish() }
        }
    }

    /// A column with the page margin and a readable maximum width, left aligned.
    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, margin)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    // MARK: Picture and headline

    /// The name and the headline, in white. The picture does not change with the mode.
    private var headline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Maru Pro")
                .font(.headline)
                .opacity(0.85)
            Text("Your next dose, at a glance.")
                // At an accessibility text size the picture would fill the whole screen, so the lines are one step smaller.
                .font(typeSize.isAccessibilitySize ? .title2.bold() : .largeTitle.bold())
                // A narrow measure breaks the line in two balanced parts: "Your next dose," and "at a glance."
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : headlineWidth, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
    }

    private var header: some View {
        column { headline }
            // The top padding keeps the text clear of the close button at a large text size.
            .padding(.top, 60)
            // The empty block under the headline holds the fade, so the fade ends before the first benefit.
            .padding(.bottom, 12 + Self.heroFade)
            // The picture runs from the top edge, under the status bar and the close button. It ends in a long, eased fade
            // into the plain background, so no black text sits on the picture or on the fade.
            .background(alignment: .top) {
                ZStack {
                    HeroArt(isStill: reduceMotion)
                    LinearGradient(
                        colors: [.black.opacity(0.1), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom
                    )
                }
                .mask {
                    VStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(stops: Self.fadeStops, startPoint: .top, endPoint: .bottom)
                            .frame(height: Self.heroFade)
                    }
                }
                .accessibilityHidden(true)
            }
    }

    /// An eased fade from opaque to clear, with no visible start or end (smootherstep).
    private static let fadeStops: [Gradient.Stop] = (0...12).map { step in
        let t = Double(step) / 12
        let eased = t * t * t * (t * (t * 6 - 15) + 10)
        return .init(color: .black.opacity(1 - eased), location: t)
    }

    /// The system close button. On iOS 26 it is the system glass "X".
    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26, *) {
            Button(role: .close) { dismiss() }
                // The app tint would color the glass button. The system close button is neutral.
                .tint(.white)
        } else {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Close")
        }
    }

    // MARK: Benefits

    /// Three rows, each a thin symbol in the tint, a semibold title, and one gray line.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 20) {
            BenefitRow(
                symbol: "lock.iphone", title: "Dose on Lock Screen", detail: "See your next dose without opening Maru."
            )
            BenefitRow(symbol: "applewatch", title: "Apple Watch", detail: "Record a dose from your wrist.")
            BenefitRow(
                symbol: "paintpalette", title: "Colors, Icons, Sounds",
                detail: "Choose your app color, icon, and sound."
            )
        }
    }

    // MARK: Purchase area

    /// Plans, the terms, the button, and the legal links. It stays at the foot of the sheet.
    private var purchase: some View {
        VStack(spacing: 12) {
            plans
            Group {
                if let notice {
                    noticeText(notice).font(.footnote)
                } else if let terms {
                    terms.font(.footnote).foregroundStyle(.secondary).minimumScaleFactor(0.9)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            buyButton
            legalLinks
        }
    }

    /// Two tiles side by side. Each plan that loaded has its own tile, so a plan never sells without its price on the
    /// display (App Review 3.1.2).
    @ViewBuilder
    private var plans: some View {
        if !model.pro.offers.isEmpty {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                if let yearly = offer(.yearly) {
                    PlanTile(
                        title: "Yearly",
                        price: yearly.displayPrice,
                        note: yearly.trialDays.map { Text("\($0) days free") },
                        isSelected: plan == .yearly
                    ) { plan = .yearly }
                }
                if let lifetime = offer(.lifetime) {
                    PlanTile(
                        title: "Lifetime",
                        price: lifetime.displayPrice,
                        note: Text("One time"),
                        isSelected: plan == .lifetime
                    ) { plan = .lifetime }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else if model.pro.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 80)
        } else {
            VStack(spacing: 12) {
                Text("Prices didn’t load. Check your connection and try again.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await model.loadProOffers() } }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
    }

    /// The terms of the selected plan, directly above the button, with its price and its period (App Review 3.1.2).
    private var terms: Text? {
        guard let selected = offer(plan) else { return nil }
        let price = selected.displayPrice
        return switch plan {
        case .yearly:
            if let days = selected.trialDays {
                Text("Free for \(days) days, then \(price) per year. Cancel anytime.")
            } else {
                Text("\(price) per year. Cancel anytime.")
            }
        case .lifetime:
            Text("One payment. Yours to keep.")
        }
    }

    private var buyButton: some View {
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
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        // A plan whose product and price did not load has no tile, so it can not be bought.
        .disabled(offer(plan) == nil || model.pro.buying != nil)
    }

    private var buyTitle: Text {
        switch plan {
        case .yearly: offer(.yearly)?.trialDays == nil ? Text("Subscribe Yearly") : Text("Start Free Trial")
        case .lifetime: Text("Buy Lifetime")
        }
    }

    // MARK: Legal links

    /// Terms of Use and Privacy Policy, quiet, on one line at the foot (App Review 3.1.2).
    private var legalLinks: some View {
        HStack(spacing: 6) {
            if let url = Self.termsURL { Link("Terms of Use", destination: url) }
            Text(verbatim: "·").accessibilityHidden(true)
            if let url = Self.privacyURL { Link("Privacy Policy", destination: url) }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .tint(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.9)
    }

    @ViewBuilder
    private func noticeText(_ notice: Notice) -> some View {
        switch notice {
        case .pending: Text("Your purchase is waiting for approval. Pro turns on when it’s approved.")
        case .failed: Text("The purchase didn’t go through. Please try again.")
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
}

/// The gradient picture. It drifts slowly and stops with Reduce Motion.
private struct HeroArt: View {
    let isStill: Bool
    var blur: CGFloat = 0
    @State private var drifts = false

    var body: some View {
        GeometryReader { proxy in
            Image("ProHero")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(1.15)
                .offset(x: drifts ? -12 : 12, y: drifts ? 8 : -8)
                .blur(radius: blur)
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

/// One paid feature: a thin symbol in the tint, a semibold title, and one line in gray. The symbols share one column.
private struct BenefitRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ScaledMetric(relativeTo: .title3) private var symbolWidth = 32

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.light))
                .foregroundStyle(.tint)
                .frame(width: symbolWidth, alignment: .leading)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One plan as a tile: the name, the price as the largest text (App Review 3.1.2), and one small line. The selected tile
/// has an outline in the tint.
private struct PlanTile: View {
    let title: LocalizedStringKey
    let price: String
    let note: Text?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(verbatim: price).font(.title2.bold())
                // A tile with no note keeps the height of its neighbor.
                (note ?? Text(verbatim: " ")).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
            PaywallView()
        }
    }
}
