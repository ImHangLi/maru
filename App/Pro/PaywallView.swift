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

    private enum Notice: Equatable {
        case pending, failed, restored, nothingToRestore
    }

    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    static let privacyURL = URL(string: "https://maru.day/privacy/")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let preview = request.preview { LockScreenPreview(dose: preview) }
                    header
                    benefits
                    plans
                    if plan == .yearly, let yearly = offer(.yearly), let days = yearly.trialDays {
                        TrialTimeline(days: days, price: yearly.displayPrice)
                    }
                    Label("Shareable with Family Sharing", systemImage: "person.2")
                        .font(.subheadline)
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
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task { await model.loadProOffers() }
        .redeemCodeSheet(isPresented: $showsRedeem)
        // A purchase that ends outside the paywall, for example an approved request, closes it too.
        .onChange(of: model.pro.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Maru Pro")
                .font(.largeTitle.bold())
            Text("A few extras for your routine. Everything you use now stays free.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            Benefit(
                symbol: "lock.iphone",
                title: "Next Dose on the Lock Screen",
                text: "See what’s next without opening Maru."
            )
            Benefit(symbol: "applewatch", title: "Apple Watch App", text: "See and record today’s doses on your wrist.")
            Benefit(symbol: "paintpalette", title: "Icons and Sounds", text: "More app icons and reminder sounds.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var plans: some View {
        if let yearly = offer(.yearly), let lifetime = offer(.lifetime) {
            HStack(alignment: .top, spacing: 12) {
                PlanCard(
                    title: "Yearly",
                    price: yearly.displayPrice,
                    period: "per year",
                    note: yearly.trialDays.map { Text("\($0) days free") },
                    isSelected: plan == .yearly
                ) { plan = .yearly }
                PlanCard(
                    title: "Lifetime",
                    price: lifetime.displayPrice,
                    period: "one time",
                    note: Text("No subscription"),
                    isSelected: plan == .lifetime
                ) { plan = .lifetime }
            }
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
            .disabled(offer(plan) == nil || model.pro.buying != nil || isRestoring)
            Button {
                dismiss()
            } label: {
                Text("Continue Free")
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
            case .purchased?: dismiss()
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
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
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
                Text(title).font(.subheadline.weight(.semibold))
                Text(verbatim: price).font(.title2.bold())
                Text(period).font(.subheadline).foregroundStyle(.secondary)
                if let note { note.font(.footnote).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.separator)), lineWidth: isSelected ? 2.5 : 1)
            }
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
        VStack(alignment: .leading, spacing: 12) {
            row(symbol: "gift", title: "Today", text: Text("Free for \(days) days"))
            row(
                symbol: "calendar",
                title: "Day \(days)",
                text: Text("\(Text(verbatim: price).bold())/year. Cancel any time in Settings.")
            )
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func row(symbol: String, title: LocalizedStringKey, text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                text
            }
        }
        .accessibilityElement(children: .combine)
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
                .background(.regularMaterial, in: .rect(cornerRadius: 22))
                .environment(\.colorScheme, .dark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [dose.color.color.opacity(0.9), .black], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: 28)
            )
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
