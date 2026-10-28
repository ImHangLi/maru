import SwiftUI

/// The second paywall of Maru Pro (D116, D117, "style B"), an option next to the plain one of D115. One gradient picture
/// is the focal point, with one headline that names the outcome. Under it come three benefits, two plans, the terms of
/// the selected plan, and a buy button that names the plan. Two looks of the lower half wait for the maintainer's choice:
///
/// - `immersive` (B1): the picture is the whole page, darker and softer toward the foot. Text is white.
/// - `clean` (B2): the picture is the top of the page and fades into the system background, under the headline.
///
/// Both use one left margin, one type scale (`largeTitle`, `headline`, `body`, `footnote`), one radius, and one accent
/// use for each kind of element. System fonts and system buttons only.
///
/// It uses the same StoreKit calls as `PaywallView` and changes no price rule, trial rule, or entitlement rule (D107).
/// The picture is `ProHero` in the asset catalog. Codex made it, and `docs/third-party-licenses.md` records it. It drifts
/// slowly, and it stands still with Reduce Motion. When the maintainer keeps one look or style, delete the rest.
struct PaywallStyleB: View {
    enum Look { case immersive, clean }

    let look: Look
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineWidth = 270
    @State private var plan = ProPlan.yearly
    @State private var notice: Notice?
    @State private var showsRedeem = false
    @State private var isRestoring = false
    @State private var isWelcoming = false
    @State private var bounce = false

    private enum Notice: Equatable {
        case pending, failed, restored, nothingToRestore
    }

    /// The one left and right margin of the page. The headline, the benefits, and the rest start on the same line.
    private let margin: CGFloat = 20
    /// The one corner radius, for the plan list.
    private let radius: CGFloat = 20
    private var isImmersive: Bool { look == .immersive }
    /// The accent of symbols and of the selected plan: the app tint on the clean page, white on the picture.
    private var accent: AnyShapeStyle { isImmersive ? AnyShapeStyle(.white) : AnyShapeStyle(.tint) }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if isImmersive { Spacer(minLength: 24) }
                    column {
                        VStack(alignment: .leading, spacing: 24) {
                            benefits
                            plans
                            actions
                        }
                    }
                    .padding(.top, isImmersive ? 0 : 4)
                    .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity, minHeight: isImmersive ? proxy.size.height : nil, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
        }
        .background {
            if isImmersive {
                immersiveBackdrop.ignoresSafeArea()
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
        }
        // The picture is dark, so the immersive page has light text, whatever the mode.
        .preferredColorScheme(isImmersive ? .dark : nil)
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

    /// A column with the page margin and a readable maximum width, left aligned.
    private func column<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, margin)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
    }

    // MARK: Picture and headline

    /// The name, the headline, and one supporting line, in white. The picture does not change with the mode.
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
            Text("Add Lock Screen, Apple Watch, and your own look. Reminders stay free.")
                .font(typeSize.isAccessibilitySize ? .callout : .body)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var header: some View {
        if isImmersive {
            // The top padding keeps the text clear of the close button at a large text size.
            column { headline }
                .padding(.top, 64)
        } else {
            let fade: CGFloat = 120
            let overlap: CGFloat = 60
            column { headline }
                .padding(.top, 64)
                .padding(.bottom, 40)
                // The picture runs from the top edge, under the status bar and the close button, and ends in a long, soft
                // fade into the page. It continues 60 points under the first benefits, so no edge shows.
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
                                .frame(height: fade)
                        }
                    }
                    .padding(.bottom, -overlap)
                    .accessibilityHidden(true)
                }
        }
    }

    /// An eased fade from opaque to clear, with no visible start or end.
    private static let fadeStops: [Gradient.Stop] = [
        .init(color: .black, location: 0),
        .init(color: .black.opacity(0.93), location: 0.15),
        .init(color: .black.opacity(0.78), location: 0.3),
        .init(color: .black.opacity(0.58), location: 0.45),
        .init(color: .black.opacity(0.38), location: 0.6),
        .init(color: .black.opacity(0.2), location: 0.75),
        .init(color: .black.opacity(0.07), location: 0.89),
        .init(color: .clear, location: 1),
    ]

    /// The picture as the whole page. A soft blur and a dark wash grow toward the foot, so the text reads.
    private var immersiveBackdrop: some View {
        ZStack {
            HeroArt(isStill: reduceMotion)
            HeroArt(isStill: true, blur: 32)
                .mask(LinearGradient(
                    stops: [.init(color: .clear, location: 0.3), .init(color: .black, location: 0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            LinearGradient(
                stops: [.init(color: .black.opacity(0.12), location: 0), .init(color: .black.opacity(0.55), location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
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

    /// Three rows, each a monochrome symbol and two to four words, with no badge and no tile.
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            BenefitRow(symbol: "lock.iphone", title: "Dose on Lock Screen", accent: accent)
            BenefitRow(symbol: "applewatch", title: "Apple Watch", accent: accent)
            BenefitRow(symbol: "paintpalette", title: "Colors, Icons, Sounds", accent: accent)
        }
    }

    // MARK: Plans

    /// One grouped list. Each plan that loaded has its own row, so a plan never sells without its price on the display
    /// (App Review 3.1.2).
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
                        isSelected: plan == .yearly,
                        accent: accent
                    ) { plan = .yearly }
                }
                if offer(.yearly) != nil, offer(.lifetime) != nil {
                    Divider().padding(.leading, 52)
                }
                if let lifetime = offer(.lifetime) {
                    PlanRow(
                        title: "Lifetime",
                        note: Text("No subscription"),
                        price: lifetime.displayPrice,
                        period: "one time",
                        isSelected: plan == .lifetime,
                        accent: accent
                    ) { plan = .lifetime }
                }
            }
            .background {
                if isImmersive {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(.secondarySystemBackground))
                }
            }
        } else if model.pro.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 100)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Prices didn’t load. Check your connection and try again.")
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await model.loadProOffers() } }
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
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

    /// The terms, then one prominent button that names the selected plan, then a quiet "Continue Free", then four small
    /// links.
    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let notice {
                    noticeText(notice).font(.footnote)
                } else if let terms {
                    terms.font(.footnote).foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 4)
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
                .foregroundStyle(isImmersive ? Color.black : Color.white)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .modifier(WhiteTint(isOn: isImmersive))
            // A plan whose product and price did not load has no row, so it can not be bought.
            .disabled(offer(plan) == nil || model.pro.buying != nil || isRestoring)
            Button {
                dismiss()
            } label: {
                Text("Continue Free")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            links
        }
    }

    private var buyTitle: Text {
        switch plan {
        case .yearly: offer(.yearly)?.trialDays == nil ? Text("Subscribe Yearly") : Text("Start Free Trial")
        case .lifetime: Text("Buy Lifetime")
        }
    }

    /// Four small links in secondary gray, left aligned.
    private var links: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .tint(.secondary)
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

/// One paid feature: a monochrome symbol and two to four words. The symbols share one column, so the labels line up.
private struct BenefitRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let accent: AnyShapeStyle
    @ScaledMetric(relativeTo: .body) private var symbolWidth = 28

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(accent)
                .frame(width: symbolWidth, alignment: .leading)
                .accessibilityHidden(true)
            Text(title)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One plan as a row of the list, with a check circle. The price is as large as the name and larger than the note
/// (App Review 3.1.2).
private struct PlanRow: View {
    let title: LocalizedStringKey
    let note: Text?
    let price: String
    let period: LocalizedStringKey
    let isSelected: Bool
    let accent: AnyShapeStyle
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
                    .foregroundStyle(isSelected ? accent : AnyShapeStyle(.tertiary))
                    .frame(width: symbolWidth)
                    .accessibilityHidden(true)
                layout {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline)
                        if let note { note.font(.footnote).foregroundStyle(.secondary) }
                    }
                    if !stacked { Spacer(minLength: 8) }
                    VStack(alignment: stacked ? .leading : .trailing, spacing: 2) {
                        Text(verbatim: price).font(.headline)
                        Text(period).font(.footnote).foregroundStyle(.secondary)
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

/// Sets the tint to white for the button on the picture. A `nil` tint would reset the app tint, so the clean page skips it.
private struct WhiteTint: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn { content.tint(.white) } else { content }
    }
}
