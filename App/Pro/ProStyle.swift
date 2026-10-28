import SwiftUI

/// The look of the Maru Pro surfaces (D115): the paywall, the Pro row of Settings, and the card of Today. System fonts
/// and system materials only. New York is the serif of the system, so it needs no font file and it follows Dynamic Type.
extension Font {
    /// Display text of a Pro surface in New York. A text style keeps Dynamic Type.
    static func proDisplay(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif, weight: weight)
    }
}

/// A soft glow of the app tint behind the top of a Pro surface. Two light blobs drift slowly, and the glow fades to the
/// page. With Reduce Motion on it stands still. It draws gradients and no blur, so it stays cheap.
struct ProGlow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDrifting = false

    var body: some View {
        let strength = colorScheme == .dark ? 0.34 : 0.26
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                blob(opacity: strength, radius: size.width * 0.75)
                    .offset(x: isDrifting ? -size.width * 0.16 : size.width * 0.12, y: -size.height * 0.12)
                blob(opacity: strength * 0.7, radius: size.width * 0.6)
                    .hueRotation(.degrees(32))
                    .offset(x: isDrifting ? size.width * 0.2 : -size.width * 0.1, y: size.height * 0.02)
            }
            .frame(width: size.width, height: size.height)
        }
        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { isDrifting = true }
        }
    }

    private func blob(opacity: Double, radius: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [Color.accentColor.opacity(opacity), Color.accentColor.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: radius / 2
            ))
            .frame(width: radius, height: radius)
    }
}

/// A rounded square with a white symbol on a gradient of the app tint, as the icons in the Settings app.
struct ProBadge: View {
    let symbol: String
    var size: CGFloat = 29

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(LinearGradient(
                colors: [Color.accentColor.opacity(0.78), Color.accentColor],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
