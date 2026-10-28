import MaruCore
import SwiftUI

/// The card of Maru Pro at the bottom of Today (D107). It is a part of the list, never a sheet, and it never pushes a
/// dose down. `AppModel.showsProCard` has the rules. "×" hides it for good.
struct ProCardSection: View {
    @Environment(AppModel.self) private var model
    let date: LocalDate

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                ProBadge(symbol: "lock.iphone", size: 36)
                VStack(alignment: .leading, spacing: 6) {
                    Text("See your next dose on the Lock Screen")
                        .font(.proDisplay(.headline))
                    Text("Maru Pro adds this, an Apple Watch app, and more colors, icons, and sounds. Everything else stays free.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("See Maru Pro") { model.presentPaywall(reason: .day7Card) }
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                // The list moves with the layout motion of Today.
                Button("Hide", systemImage: "xmark") { model.dismissProCard() }
                .labelStyle(.iconOnly)
                .foregroundStyle(.secondary)
            }
            // Two buttons in one row of a list.
            .buttonStyle(.borderless)
            .padding(.vertical, 4)
        }
        // A soft wash of the app tint, so the card reads as an invitation and not as a dose.
        .listRowBackground(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.14), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .background(Color(.secondarySystemGroupedBackground))
        )
        .onAppear { model.proCardDidShow(on: date) }
    }
}
