import SwiftUI
import UIKit

/// One setting that the search field of Settings can find (D135). The search compares the text in the app language
/// and the English source text, so an English word also finds a setting in another language.
struct SettingsSearchEntry: Identifiable {
    enum Target {
        case pages([SettingsPage])
        case paywall
        case language
        case feedback
    }

    let title: LocalizedStringResource
    /// More words that find the setting, for example "dark" for "Appearance".
    var keywords: LocalizedStringResource?
    /// The pages above the setting, for the line under the title. Empty for a row of the root.
    let location: [LocalizedStringResource]
    let target: Target

    var id: String { title.key }

    func matches(_ query: String) -> Bool {
        [title, keywords].compactMap(\.self).contains { text in
            String(localized: text).localizedStandardContains(query) || text.key.localizedStandardContains(query)
        }
    }

    /// The place of the setting, for example "Reminders › For All Items".
    var locationText: String {
        location.isEmpty
            ? String(localized: "Settings")
            : location.map { String(localized: $0) }.joined(separator: " › ")
    }

    /// Every setting that the device and the plan show, in the order of the pages.
    @MainActor static func all(for model: AppModel) -> [SettingsSearchEntry] {
        let reminders: LocalizedStringResource = "Reminders"
        let display: LocalizedStringResource = "Display"
        let data: LocalizedStringResource = "Your Data"
        let privacy: LocalizedStringResource = "Privacy"
        let about: LocalizedStringResource = "About"
        let purchases: LocalizedStringResource = "Purchases"
        var entries: [SettingsSearchEntry] = [
            .init(
                title: "Maru Pro",
                keywords: "pro, subscription, premium, upgrade, purchase",
                location: [],
                target: model.pro.isPro ? .pages([.purchases]) : .paywall
            ),
            .init(title: "Purchases", location: [], target: .pages([.purchases])),
        ]
        if model.pro.plan == .yearly {
            entries.append(.init(title: "Manage Subscription", location: [purchases], target: .pages([.purchases])))
        }
        entries += [
            .init(title: "Restore Purchases", location: [purchases], target: .pages([.purchases])),
            .init(title: "Redeem Code", location: [purchases], target: .pages([.purchases])),
            .init(
                title: "Family",
                keywords: "family, person, people, pet, member",
                location: [],
                target: .pages([.family])
            ),
            .init(title: "Add Person or Pet", location: ["Family"], target: .pages([.family])),
            .init(title: "Reminders", location: [], target: .pages([.reminders])),
            .init(
                title: "Notifications",
                keywords: "notifications, alerts, permission",
                location: [reminders],
                target: .pages([.reminders])
            ),
            .init(title: "Show Names in Reminders", location: [reminders], target: .pages([.reminders])),
            .init(
                title: "Reminder Sound",
                keywords: "sound, tone, ringtone",
                location: [reminders],
                target: .pages([.reminders, .reminderSound])
            ),
        ]
        if #available(iOS 26, *) {
            entries.append(.init(title: "Alarm", location: [reminders, "For All Items"], target: .pages([.reminders])))
        }
        entries.append(.init(
            title: "Remind Again",
            keywords: "follow-up, repeat, again",
            location: [reminders, "For All Items"],
            target: .pages([.reminders])
        ))
        if UIDevice.current.userInterfaceIdiom == .phone {
            entries.append(.init(
                title: "Next Dose on Lock Screen",
                keywords: "lock screen, live activity",
                location: ["Lock Screen"],
                target: .pages([.lockScreen])
            ))
        }
        entries += [
            .init(title: "Display", location: [], target: .pages([.display])),
            .init(
                title: "Appearance",
                keywords: "dark, light, theme, mode",
                location: [display],
                target: .pages([.display])
            ),
            .init(title: "App Color", keywords: "color, tint", location: [display], target: .pages([.display])),
        ]
        if UIApplication.shared.supportsAlternateIcons {
            entries.append(.init(title: "App Icon", location: [display], target: .pages([.display, .appIcon])))
        }
        entries += [
            .init(title: "Color Header", location: [display], target: .pages([.display])),
            .init(title: "Language", location: [], target: .language),
            .init(
                title: "Your Data",
                keywords: "export, backup, restore, file",
                location: [],
                target: .pages([.data])
            ),
            .init(title: "Export Records", location: [data], target: .pages([.data])),
            .init(title: "Share Medication List", location: [data], target: .pages([.data])),
            .init(title: "Share Summary…", location: [data], target: .pages([.data])),
            .init(title: "Back Up", location: [data], target: .pages([.data])),
            .init(title: "Restore from Backup…", location: [data], target: .pages([.data])),
            .init(title: "Privacy", location: [], target: .pages([.privacy])),
        ]
        if model.analyticsIsAvailable {
            entries.append(.init(
                title: "Share Usage Statistics",
                keywords: "analytics, statistics",
                location: [privacy],
                target: .pages([.privacy])
            ))
        }
        entries += [
            .init(title: "Privacy Policy", location: [privacy], target: .pages([.privacy])),
            .init(
                title: "Send Feedback",
                keywords: "feedback, contact, help, bug",
                location: [],
                target: .feedback
            ),
            .init(title: "About", location: [], target: .pages([.about])),
            .init(title: "Version", location: [about], target: .pages([.about])),
            .init(title: "Support", location: [about], target: .pages([.about])),
            .init(title: "Terms of Use", location: [about], target: .pages([.about])),
            .init(title: "Licenses", location: [about], target: .pages([.about, .licenses])),
        ]
        return entries
    }
}

/// A search result: the title, and the place of the setting under it.
struct SettingsSearchRow: View {
    let entry: SettingsSearchEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                    Text(verbatim: entry.locationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .rowText()
    }
}
