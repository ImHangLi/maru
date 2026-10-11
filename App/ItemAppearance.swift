import MaruCore
import SwiftUI
import UIKit

extension ItemColor {
    /// The system color with the same name. Each one has a light and a dark value (docs/design.md, Color).
    var color: Color {
        switch self {
        case .pink: .pink
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .blue: .blue
        case .purple: .purple
        case .brown: .brown
        }
    }

    /// The app tint in this color (D025). In light mode, orange, yellow, green, and mint are darker,
    /// so text and controls in the tint have at least 3:1 contrast on white. Dark mode uses the system color.
    var tint: Color {
        let light: UIColor
        switch self {
        case .orange: light = UIColor(red: 0xD9 / 255, green: 0x7F / 255, blue: 0x00 / 255, alpha: 1)
        case .yellow: light = UIColor(red: 0xB4 / 255, green: 0x90 / 255, blue: 0x00 / 255, alpha: 1)
        case .green: light = UIColor(red: 0x2C / 255, green: 0xAA / 255, blue: 0x4C / 255, alpha: 1)
        case .mint: light = UIColor(red: 0x00 / 255, green: 0xA6 / 255, blue: 0x9F / 255, alpha: 1)
        default: return color
        }
        let system = UIColor(color)
        return Color(UIColor { $0.userInterfaceStyle == .dark ? system.resolvedColor(with: $0) : light })
    }

    /// The black or white label on a fill in the app tint (D025).
    var labelOnTint: Color { tint.labelOnFill }

    var title: LocalizedStringKey {
        switch self {
        case .pink: "Pink"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .mint: "Mint"
        case .blue: "Blue"
        case .purple: "Purple"
        case .brown: "Brown"
        }
    }
}

extension Color {
    /// A filled circle in this color for a system menu. A menu draws a template image in one color,
    /// so this image keeps its own color.
    var circleImage: Image {
        let circle = UIImage(systemName: "circle.fill") ?? UIImage()
        return Image(uiImage: circle.withTintColor(UIColor(self), renderingMode: .alwaysOriginal))
    }

    /// The label color on a fill in this color (D025). White stays when it has at least 3:1 contrast on the fill.
    /// A brighter fill, such as yellow or mint in dark mode, gets black. The light and dark values are checked separately.
    var labelOnFill: Color {
        let fill = UIColor(self)
        return Color(UIColor { traits in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            fill.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
            // White on the fill has a contrast of 1.05 / (luminance + 0.05).
            return 1.05 / (luminance + 0.05) >= 3 ? .white : .black
        })
    }
}

extension ItemForm {
    /// A two-tone template image in `Icons.xcassets` (D013). An unknown form shows a jar.
    var image: Image {
        Image(self == .unknown ? "form-jar" : "form-\(rawValue)")
    }

    var title: LocalizedStringKey {
        switch self {
        case .capsule: "Capsule"
        case .tablet: "Tablet"
        case .softgel: "Softgel"
        case .powder: "Powder"
        case .drop: "Drops"
        case .unknown: "Not sure"
        }
    }
}

/// The form icon of an item in the item color. The color is never the only signal of a state (spec 5.3).
struct FormIcon: View {
    let form: ItemForm
    let color: ItemColor
    /// The icon has a size limit, and it hides at the three largest text sizes (docs/design.md).
    @ScaledMetric(relativeTo: .body) private var size = 28
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize < .accessibility3 {
            form.image
                .resizable()
                .scaledToFit()
                .frame(width: min(size, 44), height: min(size, 44))
                .foregroundStyle(color.color)
                .accessibilityHidden(true)
        }
    }
}
