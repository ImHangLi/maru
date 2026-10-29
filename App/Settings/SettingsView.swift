import MaruCore
import MaruNotifications
import SwiftUI
import UIKit

/// The settings sheet behind the gear button (spec 3 P06, D020, D021). The root is a short list of pages, as in iOS
/// Settings, with a search field at the top (D135).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    @AppStorage(DisplaySetting.appearance) private var appearance = AppAppearance.system
    @State private var path: [SettingsPage] = []
    @State private var query = ""
    /// A color that a free user chose and did not buy. It tints only this sheet, until the sheet closes (D114).
    @State private var previewColor: ItemColor?

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if searchText.isEmpty {
                    pages
                } else {
                    ForEach(results) { entry in
                        SettingsSearchRow(entry: entry) { open(entry.target) }
                    }
                }
            }
            .overlay {
                if !searchText.isEmpty && results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            #if DEBUG
            .modifier(DebugDataBanner())
            #endif
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsPage.self) { page in
                destination(page)
            }
            .toolbar {
                // A restore replaces the data while it runs. The sheet stays until it ends (D040).
                if !model.transfer.isRestoring {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        // A paywall from a row of Settings shows over this sheet (D107).
        .paywallHost(true)
        .interactiveDismissDisabled(model.transfer.isRestoring)
        // The sheet sets the tint again, so every control in it changes at once with a new app color. A preview of a
        // free user tints only this sheet (D114).
        .tint((previewColor ?? appColor).tint)
        // A purchase while a preview shows keeps the color of the preview.
        .onChange(of: model.pro.isPro) { _, isPro in
            if isPro, let previewColor { chooseAppColor(previewColor) }
        }
        // A return from the Settings app shows the new permission (T14).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.readNotificationPermission() }
        }
    }

    /// The root list: Maru Pro at the top (D107), then the groups of pages.
    @ViewBuilder private var pages: some View {
        ProSection()
        Section {
            // As the Family row of iOS Settings, with the avatars at its end (D121).
            NavigationLink(value: SettingsPage.family) {
                LabeledContent {
                    if model.hasFamily {
                        // The initials of the avatars must not move the separator under the row.
                        AvatarStack(people: model.activePeople)
                            .alignmentGuide(.listRowSeparatorLeading) { $0[.trailing] }
                    }
                } label: {
                    SettingsRowLabel("Family", systemImage: "person.2")
                }
            }
            NavigationLink(value: SettingsPage.reminders) {
                LabeledContent {
                    Text(ReminderSection.statusText(model.settings.permission))
                } label: {
                    SettingsRowLabel("Reminders", systemImage: "bell")
                }
            }
            // The iPad has no Live Activities, so it has no Lock Screen page (D110).
            if UIDevice.current.userInterfaceIdiom == .phone {
                NavigationLink(value: SettingsPage.lockScreen) {
                    LabeledContent {
                        Text(model.liveActivity.isOn ? LocalizedStringKey("On") : "Off")
                    } label: {
                        // The whole page is Maru Pro, so the row has the badge (D134).
                        SettingsRowLabel("Lock Screen", systemImage: "lock", isPro: true)
                    }
                }
            }
        }
        Section {
            NavigationLink(value: SettingsPage.display) {
                LabeledContent {
                    Text(appearance.title)
                } label: {
                    SettingsRowLabel("Display", systemImage: "sun.max")
                }
            }
            // iOS sets the app language on the Settings page of Maru (D097).
            Button { openLanguageSettings() } label: {
                LabeledContent {
                    Text(verbatim: Self.languageName)
                } label: {
                    SettingsRowLabel("Language", systemImage: "globe")
                }
            }
            .rowText()
        }
        Section {
            NavigationLink(value: SettingsPage.data) {
                SettingsRowLabel("Your Data", systemImage: "externaldrive")
            }
            NavigationLink(value: SettingsPage.privacy) {
                SettingsRowLabel("Privacy", systemImage: "hand.raised")
            }
        }
        FeedbackSection()
        #if DEBUG
        DebugSection()
        #endif
    }

    @ViewBuilder private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .purchases: PurchasesPage()
        case .family: FamilyPage()
        case .reminders: RemindersPage()
        case .reminderSound: ReminderSoundView()
        case .lockScreen: LockScreenPage()
        case .display:
            DisplayPage(color: previewColor ?? appColor, isPreview: previewColor != nil) { chooseAppColor($0) }
        case .appIcon: AppIconView()
        case .data: DataPage()
        case .privacy: PrivacyPage()
        case .about: AboutPage()
        case .licenses: LicensesView()
        }
    }

    private var searchText: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [SettingsSearchEntry] {
        SettingsSearchEntry.all(for: model).filter { $0.matches(searchText) }
    }

    private func open(_ target: SettingsSearchEntry.Target) {
        switch target {
        case let .pages(pages): path = pages
        case .paywall: model.presentPaywall(reason: .settings)
        case .language: openLanguageSettings()
        case .feedback: FeedbackSection.open(model: model, openURL: openURL)
        }
    }

    private func openLanguageSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    /// Pink is free. Another color needs Pro, also after Pro ends, so a free user sees a preview and the paywall (D114).
    private func chooseAppColor(_ color: ItemColor) {
        guard color == .pink || color == appColor || model.pro.isPro else {
            previewColor = color
            return model.presentPaywall(reason: .appColor)
        }
        previewColor = nil
        guard color != appColor else { return }
        appColor = color
        model.appColorDidChange(color)
    }

    /// The name of the language that the app uses, in that language, for example "English" or "日本語".
    private static var languageName: String {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en"
        let locale = Locale(identifier: identifier)
        return locale.localizedString(forIdentifier: identifier)?.capitalized(with: locale) ?? identifier
    }
}

/// A page of the settings sheet. The root rows and the search results push these values (D135).
enum SettingsPage: Hashable {
    case purchases, family, reminders, reminderSound, lockScreen, display, appIcon, data, privacy, about, licenses
}

/// The label of a row on the root of Settings: a symbol in the app tint, then the title in the text color (D076, D135).
/// Every symbol has the size of an item icon (`FormIcon`, 28 points) and sits centered in a column as wide as the Maru Pro
/// icon, so the icons of the app match and the titles line up with "Maru Pro" (D136).
struct SettingsRowLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isPro = false
    /// The width of the icon of the Maru Pro card (ProSection).
    @ScaledMetric(relativeTo: .body) private var column = 40
    /// The box of an item icon (`FormIcon`).
    @ScaledMetric(relativeTo: .body) private var box = 28

    init(_ title: LocalizedStringKey, systemImage: String, isPro: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.isPro = isPro
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: box * 0.8, weight: .regular))
                .foregroundStyle(.tint)
                .frame(width: min(box, 44), height: min(box, 44))
                .frame(width: column)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text(title).rowText()
                if isPro { ProBadge() }
            }
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The page "Display": "Appearance", "App Color", "App Icon", and "Color Header".
private struct DisplayPage: View {
    @Environment(AppModel.self) private var model
    @AppStorage(DisplaySetting.headerWash) private var headerWash = true
    @AppStorage(DisplaySetting.appearance) private var appearance = AppAppearance.system
    /// The color on the display: the app color, or the preview of a free user (D114).
    let color: ItemColor
    let isPreview: Bool
    let choose: (ItemColor) -> Void

    var body: some View {
        Form {
            Section {
                // The system look, or always light or dark (D105).
                Picker("Appearance", selection: Binding(get: { appearance }, set: {
                    appearance = $0
                    model.appearanceDidChange($0)
                })) {
                    ForEach(AppAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Color.primary)
                // A system menu of the eight colors (D025, D026). Only pink is free (D114).
                Picker(selection: Binding(get: { color }, set: { choose($0) })) {
                    ForEach(ItemColor.allCases, id: \.self) { item in
                        Label { Text(item.title) } icon: { item.tint.circleImage }
                            .tag(item)
                    }
                } label: {
                    ProRowTitle("App Color")
                }
                .pickerStyle(.menu)
                .tint(Color.primary)
                // The icons of Maru Pro, with a free look at each one (D112).
                if UIApplication.shared.supportsAlternateIcons {
                    NavigationLink(value: SettingsPage.appIcon) {
                        LabeledContent {
                            AppIconPreview(icon: model.settings.appIcon, size: 29)
                                .accessibilityLabel(Text(model.settings.appIcon.title))
                        } label: {
                            ProRowTitle("App Icon")
                        }
                    }
                }
                // The wash of the app color behind the title, as in Apple Health (D100).
                // A binding of its own sends the change of the user only, not the change of a restore (D127).
                Toggle("Color Header", isOn: Binding(get: { headerWash }, set: {
                    headerWash = $0
                    model.headerWashDidChange($0)
                }))
            } footer: {
                if isPreview {
                    Text("This is a preview. With Maru Pro, the whole app uses this color.")
                }
            }
        }
        .navigationTitle("Display")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// "Share Usage Statistics" and the privacy policy (spec 10, spec 11).
private struct PrivacyPage: View {
    @Environment(AppModel.self) private var model
    @State private var sharesStatistics = false

    var body: some View {
        Form {
            if model.analyticsIsAvailable {
                Section {
                    Toggle("Share Usage Statistics", isOn: Binding(
                        get: { sharesStatistics },
                        set: {
                            sharesStatistics = $0
                            model.setSharesUsageStatistics($0)
                        }
                    ))
                } footer: {
                    Text("Never includes item names, doses, or times.")
                }
            }
            Section {
                if let url = AboutPage.privacyURL { Link("Privacy Policy", destination: url).rowText() }
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sharesStatistics = model.sharesUsageStatistics }
    }
}
