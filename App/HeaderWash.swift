import MaruCore
import SwiftUI
import UIKit

extension View {
    /// The header wash of a main tab page, when "Color Header" is on in Settings (D100).
    /// Put it on the list or the scroll view of the page. Off, it changes nothing.
    func headerWash() -> some View {
        modifier(HeaderWashModifier())
    }
}

private struct HeaderWashModifier: ViewModifier {
    @AppStorage(DisplaySetting.headerWash) private var isOn = false
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    /// How far the content scrolled up from its rest place. It stops at the end of the wash, so a longer scroll changes nothing.
    @State private var scrolled: CGFloat = 0

    func body(content: Content) -> some View {
        content
            // The page color under a list comes from the page, so the wash can show between the two.
            .scrollContentBackground(isOn ? .hidden : .automatic)
            .background(alignment: .top) {
                if isOn { HeaderWash(color: appColor, scrolled: scrolled) }
            }
            .modifier(ScrollDistance(isOn: isOn, distance: $scrolled))
    }
}

/// Reads the scroll distance for the wash. Before iOS 18 SwiftUI can not read it, so the wash stays in place.
private struct ScrollDistance: ViewModifier {
    let isOn: Bool
    @Binding var distance: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            let isOn = isOn
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                guard isOn else { return 0 }
                let value = geometry.contentOffset.y + geometry.contentInsets.top
                return min(max(value, -HeaderWash.overscroll), HeaderWash.height)
            } action: { _, new in
                distance = new
            }
        } else {
            content
        }
    }
}

/// A wash of the app tint behind the large title, after the Summary screen of Apple Health (D021, D100, docs/design.md).
///
/// Measured on iOS 27: one color across the full width, strongest at the top edge of the screen,
/// gone after 280 pt. It moves with the content, so it scrolls away. Solid color above it
/// covers the pull-down of the scroll view. The cards stay opaque on top of it.
struct HeaderWash: View {
    let color: ItemColor
    let scrolled: CGFloat

    /// How much of the top color is left at each point of the fade, from the measurement.
    private static let fade: [(location: Double, amount: Double)] = [
        (0, 1), (0.16, 0.96), (0.27, 0.90), (0.37, 0.82), (0.48, 0.72),
        (0.58, 0.60), (0.69, 0.41), (0.79, 0.23), (0.90, 0.10), (1, 0),
    ]
    nonisolated static let height: CGFloat = 280
    nonisolated static let overscroll: CGFloat = 800

    var body: some View {
        let top = Self.top(color)
        VStack(spacing: 0) {
            top.frame(height: Self.overscroll)
            LinearGradient(
                stops: Self.fade.map { .init(color: top.opacity($0.amount), location: $0.location) },
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.height)
        }
        .offset(y: -(Self.overscroll + scrolled))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The app tint mixed with white in light mode and with black in dark mode, to the relative luminance of
    /// Apple's top colors: 0.54 in light mode (#FFB08A in Health) and 0.09 in dark mode (#933813 in Health).
    /// So every app color gives a wash of the same strength, and the title text keeps more than 7:1 contrast.
    nonisolated private static func top(_ color: ItemColor) -> Color {
        let tint = UIColor(color.tint)
        return Color(UIColor { traits in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            tint.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: nil)
            if traits.userInterfaceStyle == .dark {
                return tone(luminance: 0.09) { UIColor(red: red * (1 - $0), green: green * (1 - $0), blue: blue * (1 - $0), alpha: 1) }
            }
            return tone(luminance: 0.54) { amount in
                func mix(_ value: CGFloat) -> CGFloat { 1 - amount + value * amount }
                return UIColor(red: mix(red), green: mix(green), blue: mix(blue), alpha: 1)
            }
        })
    }

    /// Finds the color on a one-parameter scale whose relative luminance is the target.
    /// The scale must get darker as the parameter grows.
    nonisolated private static func tone(luminance target: Double, _ make: (CGFloat) -> UIColor) -> UIColor {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            func linear(_ c: CGFloat) -> Double { c <= 0.04045 ? Double(c) / 12.92 : pow((Double(c) + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        var low: CGFloat = 0, high: CGFloat = 1
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if luminance(make(mid)) > target { low = mid } else { high = mid }
        }
        return make((low + high) / 2)
    }
}
