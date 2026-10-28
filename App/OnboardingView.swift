import SwiftUI

/// The short first-run onboarding (D103): three pages, shown once, only when the store has no item.
/// It asks nothing and requests no permission. The notification permission comes with the first save
/// that has a reminder time (spec 2.2).
enum Onboarding {
    /// `true` after the first read of the store, also when the store had items and the pages did not show.
    /// It is a preference in `UserDefaults.standard`, as the app color (D023), not in the health database.
    static let seenKey = "onboarding.seen"
}

struct OnboardingView: View {
    /// `true` when the user chose to add an item. The caller opens the edit screen after the sheet closes.
    let finish: (_ addsItem: Bool) -> Void
    @State private var page = Page.promise

    private enum Page: Int, CaseIterable {
        case promise, privacy, start
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage(
                        symbol: "checkmark.circle",
                        title: Text("Did I take it? Open Maru and you know."),
                        text: Text("Maru reminds you on time, and one tap records each dose.")
                    )
                    .tag(Page.promise)
                    OnboardingPage(
                        symbol: "lock",
                        title: Text("Stays on Your iPhone"),
                        text: Text("There’s no account to make and no ads. What you take is yours alone.")
                    )
                    .tag(Page.privacy)
                    OnboardingPage(
                        symbol: "pills",
                        title: Text("Ready When You Are"),
                        text: Text("Add a supplement or medication. You choose the time, and Maru reminds you.")
                    )
                    .tag(Page.start)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                // The dots stay visible on the white page of light mode.
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                buttons
                    .padding(.horizontal, Tile.margin)
                    .padding(.bottom, Tile.margin)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { finish(false) }
                }
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        VStack(spacing: 8) {
            if page == .start {
                Button { finish(true) } label: {
                    Text("Add Item").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button { finish(false) } label: {
                    Text("Later").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    // A page change by the button moves like a swipe, and with Reduce Motion it shows at once.
                    withMotion(.layout) { page = Page(rawValue: page.rawValue + 1) ?? .start }
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
    }
}

/// One page: a symbol in the tint, a title, and one sentence. It scrolls at the largest text sizes.
private struct OnboardingPage: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let symbol: String
    let title: Text
    let text: Text

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // The symbol is decoration. At the three largest text sizes it gives its room to the words (D013).
                if typeSize < .accessibility3 {
                    Image(systemName: symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
                title
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                text
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 32)
            // The page dots sit at the bottom of the page, under the words.
            .padding(.top, 48)
            .padding(.bottom, 64)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}
