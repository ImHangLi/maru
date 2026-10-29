import SwiftUI

/// "Maru Pro" at the top of Settings (D107). For a free user, the card opens the paywall. For a Pro user, it shows the
/// plan. The row "Purchases" under it opens "Manage Subscription", "Restore Purchases", and "Redeem Code" (D135).
struct ProSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            if let plan = model.pro.plan {
                HStack(spacing: 12) {
                    AppIconPreview(icon: model.settings.appIcon, size: 40)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maru Pro").font(.headline)
                        Text(plan == .yearly ? "Active, Yearly" : "Active, Lifetime")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Button {
                    model.presentPaywall(reason: .settings)
                } label: {
                    HStack(spacing: 12) {
                        AppIconPreview(icon: model.settings.appIcon, size: 40)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Maru Pro").font(.headline)
                            Text("Lock Screen, Apple Watch, and more")
                                .font(.subheadline)
                                .opacity(0.85)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .opacity(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                }
                // The art of the paywall, so the card looks like the place it opens (D137).
                .listRowBackground(ProCardBackground())
            }
            NavigationLink(value: SettingsPage.purchases) {
                SettingsRowLabel("Purchases", systemImage: "creditcard")
            }
        } footer: {
            if !model.pro.isPro {
                Text("Reminders, records, and your data stay free.")
            }
        }
    }
}

/// "Manage Subscription" for a yearly plan, "Restore Purchases", and "Redeem Code" (D107, D135).
struct PurchasesPage: View {
    @Environment(AppModel.self) private var model
    @State private var showsRedeem = false
    @State private var showsManage = false
    @State private var isRestoring = false
    @State private var restoreNotice: LocalizedStringKey?

    var body: some View {
        Form {
            Section {
                if model.pro.plan == .yearly {
                    Button("Manage Subscription") { showsManage = true }
                        .rowText()
                        .manageSubscriptionSheet(isPresented: $showsManage)
                }
                // The system sheets and the alert sit on the rows. A modifier on a section of a form can apply to each row.
                Button("Restore Purchases") { restore() }
                    .rowText()
                    .disabled(isRestoring)
                    .alert(
                        "Restore Purchases",
                        isPresented: Binding(get: { restoreNotice != nil }, set: { if !$0 { restoreNotice = nil } })
                    ) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        if let restoreNotice { Text(restoreNotice) }
                    }
                Button("Redeem Code") { showsRedeem = true }
                    .rowText()
                    .redeemCodeSheet(isPresented: $showsRedeem)
            }
        }
        .navigationTitle("Purchases")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restore() {
        isRestoring = true
        Task {
            switch await model.restorePro() {
            case .restored?: restoreNotice = "Maru Pro is back. Thank you."
            case nil: restoreNotice = "No Maru Pro purchase was found for this Apple Account."
            case .failed?: restoreNotice = "The restore didn’t go through. Please try again."
            case .cancelled?, .purchased?, .pending?, .dismissed?: break
            }
            isRestoring = false
        }
    }
}

/// The background of the Maru Pro card for a free user: the slow art of the paywall, a dark wash for the white text, and
/// one light sweep when Settings opens. With Reduce Motion the art stays still and there is no sweep (D137).
private struct ProCardBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeps = false

    var body: some View {
        ZStack {
            HeroArt(isStill: reduceMotion)
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
            GeometryReader { proxy in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.4)
                .rotationEffect(.degrees(20))
                .offset(x: sweeps ? proxy.size.width * 1.2 : -proxy.size.width * 0.6)
                .opacity(reduceMotion ? 0 : 1)
            }
            .allowsHitTesting(false)
        }
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeInOut(duration: 1.4)) { sweeps = true }
        }
    }
}
