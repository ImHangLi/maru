import MaruCore
import SwiftUI

/// The paywall of Maru Pro (D107): one screen with the benefits, the two plans side by side, the trial timeline, and a
/// "Continue Free" button with the same weight as the buy button. No countdown, no trial switch, and no discount.
///
/// It is a custom view, because `SubscriptionStoreView` shows one subscription group and cannot sell the lifetime
/// plan beside it. The prices come from StoreKit through `ProStore`. The view never reads or writes health data.
struct PaywallView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let request: PaywallRequest
    @State private var plan = ProPlan.yearly
    @State private var notice: Notice?
    @State private var showsRedeem = false
    @State private var isRestoring = false
    @State private var isWelcoming = false
    @State private var bounce = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Notice: Equatable {
        case pending, failed, restored, nothingToRestore
    }

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyURL = URL(string: "https://maru.day/privacy/")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if let preview = request.preview { LockScreenPreview(dose: preview) }
                    header
                    benefits
                    showcase
                    plans
                    if plan == .yearly, let yearly = offer(.yearly), let days = yearly.trialDays {
                        TrialTimeline(days: days, price: yearly.displayPrice)
                    }
                    Label("Shareable with Family Sharing", systemImage: "person.2")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if let notice {
                        noticeText(notice)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                    buttons
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                // The glow scrolls away with the hero.
                .background(alignment: .top) { ProGlow().frame(height: 460).offset(y: -40) }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background {
                Color(.systemBackground).ignoresSafeArea()
            }
            .overlay { if isWelcoming { welcome } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await model.loadProOffers() }
        // When only the other plan loaded, select it, so the buy button sells the plan whose card shows.
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
        VStack(spacing: 14) {
            AppIconPreview(icon: model.settings.appIcon, size: 76)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                .accessibilityHidden(true)
            Text("Maru Pro")
                .font(.proDisplay(.largeTitle))
                .accessibilityAddTraits(.isHeader)
            Text("A few extras for your routine. Everything you use now stays free.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 0) {
            Benefit(
                symbol: "lock.iphone",
                title: "Next Dose on the Lock Screen",
                text: "See what’s next without opening Maru."
            )
            Divider().padding(.leading, 62)
            Benefit(symbol: "applewatch", title: "Apple Watch App", text: "See and record today’s doses on your wrist.")
            Divider().padding(.leading, 62)
            Benefit(symbol: "paintpalette", title: "Make It Yours", text: "App colors, icons, and reminder sounds.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .proCard()
    }

    /// The colors, icons, and sounds that Pro unlocks, as the real ones. The sounds play for free, as in Settings (D112).
    private var showcase: some View {
        VStack(alignment: .leading, spacing: 18) {
            showcaseRow("App Color") {
                HStack(spacing: 10) {
                    ForEach(ItemColor.allCases, id: \.self) { color in
                        Circle().fill(color.tint).frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
                    }
                }
                .accessibilityHidden(true)
            }
            showcaseRow("App Icon") {
                HStack(spacing: 10) {
                    ForEach(AppIcon.allCases) { icon in AppIconPreview(icon: icon, size: 44) }
                }
                .accessibilityHidden(true)
            }
            showcaseRow("Reminder Sound") {
                HStack(spacing: 8) {
                    ForEach(ReminderSound.allCases) { sound in
                        Button {
                            SoundPreview.shared.play(sound)
                        } label: {
                            Label { Text(sound.title) } icon: { Image(systemName: "play.fill").imageScale(.small) }
                                .font(.footnote.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.thinMaterial, in: .capsule)
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .padding(.leading, 18)
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }

    private func showcaseRow(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.trailing, 18)
            // The row runs to the edge of the card and scrolls, so it never clips at a large text size.
            ScrollView(.horizontal, showsIndicators: false) {
                content().padding(.trailing, 18)
            }
        }
    }

    /// The thank-you after a purchase. It shows for a moment, and then the paywall closes.
    private var welcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, value: bounce)
            Text("Welcome to Maru Pro")
                .font(.proDisplay(.title))
            Text("Thank you. Your extras are ready.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
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

    /// Each plan that loaded has its own card, so a plan never sells without its price on the display (App Review 3.1.2).
    @ViewBuilder
    private var plans: some View {
        if !model.pro.offers.isEmpty {
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                if let yearly = offer(.yearly) {
                    PlanCard(
                        title: "Yearly",
                        price: yearly.displayPrice,
                        period: "per year",
                        note: yearly.trialDays.map { Text("\($0) days free") },
                        isSelected: plan == .yearly
                    ) { plan = .yearly }
                }
                if let lifetime = offer(.lifetime) {
                    PlanCard(
                        title: "Lifetime",
                        price: lifetime.displayPrice,
                        period: "one time",
                        note: Text("No subscription"),
                        isSelected: plan == .lifetime
                    ) { plan = .lifetime }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: plan)
        } else if model.pro.isLoading {
            ProgressView()
                .frame(minHeight: 120)
        } else {
            VStack(spacing: 12) {
                Text("Prices didn’t load. Check your connection and try again.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") { Task { await model.loadProOffers() } }
            }
            .frame(minHeight: 120)
        }
    }

    /// The buy button and "Continue Free" have the same size, shape, fill, and font, so neither looks like the only way on.
    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                buy()
            } label: {
                Group {
                    if model.pro.buying != nil {
                        ProgressView()
                    } else {
                        Text(plan == .yearly ? "Subscribe Yearly" : "Buy Lifetime")
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

    private var footer: some View {
        VStack(spacing: 12) {
            if plan == .yearly {
                Text("The yearly plan renews each year until you cancel it in Settings. Cancel at least 24 hours before it renews.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
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
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ProBadge(symbol: symbol, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }
}

/// One plan. The price is the largest text of the card, larger than the trial words (App Review 3.1.2).
private struct PlanCard: View {
    let title: LocalizedStringKey
    let price: String
    let period: LocalizedStringKey
    let note: Text?
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(verbatim: price).font(.proDisplay(.title, weight: .bold))
                Text(period).font(.subheadline).foregroundStyle(.secondary)
                if let note { note.font(.footnote).foregroundStyle(.secondary) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(.regularMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.08)), lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What the trial does, day by day. The billed amount is bold and as large as the trial words.
private struct TrialTimeline: View {
    let days: Int
    let price: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(symbol: "gift", title: "Today", text: Text("Free for \(days) days"))
            Divider().padding(.leading, 48)
            row(
                symbol: "calendar",
                title: "Day \(days)",
                text: Text("\(Text(verbatim: price).bold())/year. Cancel any time in Settings.")
            )
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .proCard()
    }

    private func row(symbol: String, title: LocalizedStringKey, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                text.foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    /// A calm card: a system material, a continuous corner, and a hairline edge.
    func proCard() -> some View {
        background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

/// A static picture of a Lock Screen with the user's next dose, as the Live Activity of Maru Pro will show it. It is
/// not a real activity, and it starts nothing (D107).
struct LockScreenPreview: View {
    let dose: NextDosePreview

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 14) {
                Text(Date(), format: .dateTime.hour().minute())
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                HStack(spacing: 12) {
                    FormIcon(form: dose.form, color: dose.color, photo: dose.imageReference)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Dose")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: dose.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(verbatim: ([dose.amount].compactMap(\.self) + [dose.time]).detailLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
                .environment(\.colorScheme, .dark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [dose.color.color.opacity(0.9), .black], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)
            Text("Preview of your Lock Screen")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
        )) { request in
            PaywallView(request: request)
        }
    }
}
