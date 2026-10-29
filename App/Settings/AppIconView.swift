import SwiftUI
import UIKit

/// The app icons (D112, D132). The asset catalog includes vector colors and generated ceramic artwork.
/// `project.yml` lists the alternate icons for the asset compiler.
enum AppIcon: String, CaseIterable, Identifiable {
    case pink, blue, purple, green, night, mono, roseCeramic, blueLotus, roseAndSage

    var id: Self { self }

    /// The name of the alternate icon for `setAlternateIconName`. The primary icon has none.
    var alternateName: String? {
        self == .pink ? nil : "AppIcon-\(assetName)"
    }

    var previewName: String { "IconPreview-\(self == .pink ? "Default" : assetName)" }

    private var assetName: String {
        switch self {
        case .roseCeramic: "RoseCeramic"
        case .blueLotus: "BlueLotus"
        case .roseAndSage: "RoseAndSage"
        default: rawValue.capitalized
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .pink: "Default"
        case .blue: "Blue"
        case .purple: "Purple"
        case .green: "Green"
        case .night: "Night"
        case .mono: "Mono"
        case .roseCeramic: "Rose Ceramic"
        case .blueLotus: "Blue Lotus"
        case .roseAndSage: "Rose and Sage"
        }
    }

    /// The icon on the Home Screen now. The system keeps the choice, so a reinstall shows the primary icon.
    @MainActor static var current: AppIcon {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateName == name } ?? .pink
    }
}

/// "App Icon" in Settings (D112): every icon in a grid. Every user sees each icon. A free user who chooses an icon other
/// than the default gets the paywall. The grid is a custom control, because SwiftUI has no native icon picker.
struct AppIconView: View {
    @Environment(AppModel.self) private var model
    @State private var notChanged = false

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 12)], spacing: 20) {
                    ForEach(AppIcon.allCases) { icon in
                        tile(icon)
                    }
                }
                .padding(.vertical, 12)
            } footer: {
                if !model.pro.isPro {
                    Text("Look at every icon for free. Maru Pro lets you choose one.")
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Not Changed", isPresented: $notChanged) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The icon didn’t change. Please try again.")
        }
    }

    private func tile(_ icon: AppIcon) -> some View {
        let isChosen = model.settings.appIcon == icon
        return Button {
            choose(icon)
        } label: {
            VStack(spacing: 8) {
                AppIconPreview(icon: icon, size: 62)
                    .padding(4)
                    // The ring of the chosen icon, as the chosen plan of the paywall (D107).
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(.tint, lineWidth: 2.5)
                            .opacity(isChosen ? 1 : 0)
                    )
                Text(icon.title)
                    .font(.footnote)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func choose(_ icon: AppIcon) {
        Task {
            let changed = await model.chooseAppIcon(icon)
            if !changed { notChanged = true }
        }
    }
}

/// The picture of an icon with the corner of the Home Screen. A thin edge shows a white icon on a white card.
struct AppIconPreview: View {
    let icon: AppIcon
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        Image(icon.previewName)
            .resizable()
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}
