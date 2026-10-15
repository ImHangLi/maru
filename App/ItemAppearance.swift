import MaruCore
import SwiftUI
import UIKit

extension ItemColor {
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

    /// The icon in one color for a system menu. A menu draws a template image in the color of its text,
    /// so this image keeps its own color (D076).
    func menuImage(in color: Color) -> Image {
        let name = self == .unknown ? "form-jar" : "form-\(rawValue)"
        let icon = UIImage(named: name) ?? UIImage()
        return Image(uiImage: icon.withTintColor(UIColor(color), renderingMode: .alwaysOriginal))
    }

    /// The same words as `title`, as text for a line that joins several parts (D091).
    var localizedName: String {
        switch self {
        case .capsule: String(localized: "Capsule")
        case .tablet: String(localized: "Tablet")
        case .softgel: String(localized: "Softgel")
        case .powder: String(localized: "Powder")
        case .drop: String(localized: "Drops")
        case .unknown: String(localized: "Not sure")
        }
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
    /// The photo file of the item. The photo replaces the icon when it loads, and the icon stays when there is none (D056).
    var photo: String?
    /// The icon has a size limit, and it hides at the three largest text sizes (docs/design.md).
    @ScaledMetric(relativeTo: .body) private var size = 28
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize < .accessibility3 {
            // A photo and a drawn icon share one frame, so the names in a mixed list line up (D073).
            let side = min(size * 1.4, 44)
            ItemPhotoView(reference: photo, side: side) {
                form.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(size, 44), height: min(size, 44))
                    .foregroundStyle(color.color)
            }
            .frame(width: side, height: side)
            .accessibilityHidden(true)
        }
    }
}
