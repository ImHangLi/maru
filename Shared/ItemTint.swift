import MaruCore
import SwiftUI
import UIKit

/// The colors of an item and the app tint. The app and the widgets share them (D048).
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
}
