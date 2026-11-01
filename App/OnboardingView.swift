import MaruCore
import SwiftUI

/// The short first-run onboarding (D103, D104, D145): three static pages, shown once, only when the store has no item.
/// The type, the margins, and the buttons have the values of the onboarding pages of Apple. It asks nothing and requests
/// no permission. The notification permission comes with the first save that has a reminder time (spec 2.2).
/// `AppModel+Onboarding.swift` decides when it shows.
enum Onboarding {
    /// `true` after the onboarding ends, after a read of a store with items, and after a restore.
    /// It is a preference in `UserDefaults.standard`, as the app color (D023), not in the health database.
    static let seenKey = "onboarding.seen"
}

/// The values of the onboarding pages of Apple, measured on iOS 27 (D145).
private enum Metrics {
    static let margin: CGFloat = 38
    static let wordsWidth: CGFloat = 624
    /// The width of the buttons in a regular window. A compact window has the margin on each side.
    static let regularButtonWidth: CGFloat = 326
    /// 52 points in all: the button styles add 7 points above and below the label.
    static let buttonLabelHeight: CGFloat = 38
    static let buttonSpacing: CGFloat = 10
    /// The space between the words and the first button.
    static let trayTop: CGFloat = 24
    /// The space between the last button and the edge of the screen, with or without a Home indicator.
    static let trayBottom: CGFloat = 38
}

/// One page: the answer that a new user wants, and a step toward "Add Item" (D145).
private enum OnboardingPage: CaseIterable, Identifiable {
    case answer, action, safetyNet

    var id: Self { self }

    /// A real capture, with one image for each language and appearance. iOS 17 to iOS 25 has no alarm, so its capture has
    /// no "Alarm" row.
    var picture: String {
        switch self {
        case .answer: "onboarding-today"
        case .action: "onboarding-reminder"
        case .safetyNet: AlarmSupport.isAvailable ? "onboarding-reminders" : "onboarding-reminders-no-alarm"
        }
    }

    /// The part of the picture that stays when a small window clips it.
    var pictureAlignment: Alignment {
        switch self {
        case .answer: .top
        case .action: .center
        case .safetyNet: .bottom
        }
    }

    var title: Text {
        switch self {
        case .answer: Text("Did I take it today?")
        case .action: Text("Tap Taken on the reminder")
        case .safetyNet: Text("So you don’t miss a dose")
        }
    }

    var line: Text {
        switch self {
        case .answer: Text("Today shows each dose and when you took it.")
        case .action: Text("It records the dose without opening Maru. Allow notifications when asked.")
        case .safetyNet:
            AlarmSupport.isAvailable
                ? Text("Remind Again follows up if you forget to record. Alarms ring through Silent mode and Focus.")
                : Text("Remind Again follows up if you forget to record.")
        }
    }
}

struct OnboardingView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The button that ended the onboarding. For `addItem` the caller opens the edit screen after the page closes.
    let finish: (AnalyticsEvent.OnboardingResult) -> Void
    @State private var page = OnboardingPage.answer

    private let pages = OnboardingPage.allCases

    private var isLast: Bool { page == pages.last }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    OnboardingPageView(page: item)
                        .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            buttons
                .frame(maxWidth: sizeClass == .regular ? Metrics.regularButtonWidth : .infinity)
                .padding(.horizontal, Metrics.margin)
                .padding(.bottom, Metrics.trayBottom)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        // The captures have this color around their cards, so a picture has no edge on the page.
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    /// The two buttons stay in place on every page, so only the words change.
    private var buttons: some View {
        VStack(spacing: Metrics.buttonSpacing) {
            Button {
                if isLast {
                    finish(.addItem)
                } else {
                    // A page change by the button moves like a swipe, and with Reduce Motion it shows at once.
                    withMotion(.layout) { page = pages[(pages.firstIndex(of: page) ?? 0) + 1] }
                }
            } label: {
                OnboardingButtonLabel(text: isLast ? Text("Add Item") : Text("Continue"))
            }
            .onboardingProminentButton()
            Button {
                finish(isLast ? .later : .skipped)
            } label: {
                OnboardingButtonLabel(text: isLast ? Text("Later") : Text("Skip"))
            }
            .onboardingPlainButton()
        }
        .buttonBorderShape(.capsule)
    }
}

private struct OnboardingButtonLabel: View {
    let text: Text

    var body: some View {
        text
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonLabelHeight)
    }
}

private extension View {
    @ViewBuilder func onboardingProminentButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder func onboardingPlainButton() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass).tint(.primary)
        } else {
            buttonStyle(.bordered).tint(.primary)
        }
    }
}

/// The picture fills what the words leave. At the largest text sizes the page scrolls, and the picture gives its room to
/// the words (D013).
private struct OnboardingPageView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let page: OnboardingPage

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if typeSize < .accessibility3 {
                        picture
                            .frame(minHeight: typeSize.isAccessibilitySize ? 200 : 240, maxHeight: .infinity)
                    } else {
                        Spacer(minLength: 0)
                    }
                    words
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The picture keeps the width of the page, and a small window clips it. It is decoration with sample words, so
    /// VoiceOver reads only the title and the line.
    private var picture: some View {
        GeometryReader { box in
            Image(page.picture)
                .resizable()
                .scaledToFit()
                .frame(width: box.size.width)
                .frame(width: box.size.width, height: box.size.height, alignment: page.pictureAlignment)
        }
        .clipped()
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: page.pictureAlignment == .top ? 0 : 24)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 24)
            }
        }
        .frame(maxWidth: Metrics.wordsWidth)
        .accessibilityHidden(true)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 1) {
            page.title
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            page.line
                .font(.title2)
                .lineSpacing(2)
                .foregroundStyle(.secondary)
            // The place of the privacy note on the pages of Apple.
            if page == .safetyNet {
                Text("No account. No ads.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: Metrics.wordsWidth, alignment: .leading)
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 16)
        .padding(.bottom, Metrics.trayTop)
    }
}
