import MaruCore
import SwiftUI
import UIKit

/// The short first-run onboarding (D103, D104, D145): the look of the "What's New" pages of Apple, shown once, only when
/// the store has no item. It asks nothing and requests no permission. The notification permission comes with the first
/// save that has a reminder time (spec 2.2). `AppModel+Onboarding.swift` decides when it shows.
enum Onboarding {
    /// `true` after the onboarding ends, after a read of a store with items, and after a restore.
    /// It is a preference in `UserDefaults.standard`, as the app color (D023), not in the health database.
    static let seenKey = "onboarding.seen"
}

/// One page of the onboarding: a moving picture of the product, a title, and one line.
enum OnboardingPage: Int, CaseIterable, Identifiable {
    case reminder, today, alarm

    var id: Self { self }

    /// Alarms need iOS 26, so an older system has only the first two pages (D145).
    static var shown: [OnboardingPage] {
        AlarmSupport.isAvailable ? allCases : [.reminder, .today]
    }

    var title: Text {
        switch self {
        case .reminder: Text("Reminders, Right on Time")
        case .today: Text("Did I take it today?")
        case .alarm: Text("An Alarm, If You Want One")
        }
    }

    var line: Text {
        switch self {
        case .reminder: Text("You choose the time. One tap on Taken records the dose.")
        case .today: Text("Today shows each dose and when you took it.")
        case .alarm: Text("Turn on Alarm for any item, and it rings through Silent mode and Focus.")
        }
    }

    var words: some View {
        VStack(spacing: 8) {
            title
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            line
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct OnboardingView: View {
    /// The button that ended the onboarding. For `addItem` the caller opens the edit screen after the page closes.
    let finish: (AnalyticsEvent.OnboardingResult) -> Void
    @State private var page = OnboardingPage.reminder

    private let pages = OnboardingPage.shown

    private var isLast: Bool { page == pages.last }

    var body: some View {
        GeometryReader { window in
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        OnboardingPageView(page: item, isCurrent: item == page, topInset: window.safeAreaInsets.top)
                            .tag(item)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // The picture goes under the status bar, as in the pages of Apple.
                .ignoresSafeArea(.container, edges: .top)
                footer
            }
        }
    }

    /// The dots and the two buttons stay in place on every page, so only the words change.
    private var footer: some View {
        VStack(spacing: 12) {
            OnboardingDots(count: pages.count, current: pages.firstIndex(of: page) ?? 0) { index in
                withMotion(.layout) { page = pages[index] }
            }
            VStack(spacing: 4) {
                Button {
                    if isLast {
                        finish(.addItem)
                    } else {
                        // A page change by the button moves like a swipe, and with Reduce Motion it shows at once.
                        withMotion(.layout) { page = pages[(pages.firstIndex(of: page) ?? 0) + 1] }
                    }
                } label: {
                    (isLast ? Text("Add Item") : Text("Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                Button {
                    finish(isLast ? .later : .skipped)
                } label: {
                    (isLast ? Text("Later") : Text("Skip"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }
}

/// The picture fills what the words leave. At the largest text sizes the page scrolls, and the picture gives its room to
/// the words (D013).
private struct OnboardingPageView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let page: OnboardingPage
    let isCurrent: Bool
    let topInset: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if typeSize < .accessibility3 {
                        OnboardingStage(page: page, isCurrent: isCurrent, topInset: topInset)
                            .frame(minHeight: typeSize.isAccessibilitySize ? 240 : 320, maxHeight: .infinity)
                    } else {
                        Color.clear.frame(height: topInset)
                    }
                    // The tallest words of all pages set the height, so the picture keeps its size from page to page.
                    ZStack(alignment: .top) {
                        ForEach(OnboardingPage.shown) { $0.words.hidden() }
                        page.words
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 600)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// The system page dots. A paged `TabView` draws its dots on the page, and there they do not show on the white page of
/// light mode. This control stays under the words, and it keeps the adjustable action of VoiceOver.
private struct OnboardingDots: UIViewRepresentable {
    let count: Int
    let current: Int
    let select: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(select: select) }

    func makeUIView(context: Context) -> UIPageControl {
        let dots = UIPageControl()
        dots.numberOfPages = count
        dots.backgroundStyle = .minimal
        dots.pageIndicatorTintColor = .tertiaryLabel
        dots.currentPageIndicatorTintColor = .label
        dots.addTarget(context.coordinator, action: #selector(Coordinator.changed), for: .valueChanged)
        return dots
    }

    func updateUIView(_ dots: UIPageControl, context: Context) {
        dots.currentPage = current
        context.coordinator.select = select
    }

    final class Coordinator: NSObject {
        var select: (Int) -> Void

        init(select: @escaping (Int) -> Void) { self.select = select }

        @objc func changed(_ dots: UIPageControl) { select(dots.currentPage) }
    }
}
