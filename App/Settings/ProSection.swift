import SwiftUI

/// "Maru Pro" at the top of Settings (D107). For a free user, the row opens the paywall. For a Pro user, it shows the
/// plan. "Restore Purchases" and "Redeem Code" are always here.
struct ProSection: View {
    @Environment(AppModel.self) private var model
    @State private var showsRedeem = false
    @State private var showsManage = false
    @State private var isRestoring = false
    @State private var restoreNotice: LocalizedStringKey?

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
                if plan == .yearly {
                    Button("Manage Subscription") { showsManage = true }
                        .rowText()
                        .manageSubscriptionSheet(isPresented: $showsManage)
                }
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
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .rowText()
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
        } footer: {
            if !model.pro.isPro {
                Text("Reminders, records, and your data stay free.")
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            switch await model.restorePro() {
            case .restored?: restoreNotice = "Maru Pro is back. Thank you."
            case nil: restoreNotice = "No Maru Pro purchase was found for this Apple Account."
            case .failed?: restoreNotice = "The restore didn’t go through. Please try again."
            case .cancelled?, .purchased?, .pending?: break
            }
            isRestoring = false
        }
    }
}
