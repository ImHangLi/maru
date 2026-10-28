import Foundation

/// Where the first-run onboarding is in this process (D103, D104).
enum OnboardingState: Equatable {
    /// The flag is not set, and the first read or the first open in front did not come yet. The root view shows an
    /// empty page, so Today does not show for a frame before the onboarding.
    case undecided
    case shows
    /// Not in this process: the flag is set, the store has items, or a reminder or a widget opened the app.
    case hidden

    /// With the flag set, Today shows at once and the launch does not wait for the first read (spec 9).
    static var initial: OnboardingState {
        UserDefaults.standard.bool(forKey: Onboarding.seenKey) ? .hidden : .undecided
    }
}

extension AppModel {
    /// Runs after each read and at each open in front. The onboarding shows only on a normal open in front of a store
    /// with no item, active or archived. A store with items sets the flag with no page, also after an update (D104).
    func updateOnboarding() {
        guard case let .loaded(snapshot) = content else { return }
        guard snapshot.list.isEmpty && snapshot.archived.isEmpty else {
            if onboarding != .shows, !UserDefaults.standard.bool(forKey: Onboarding.seenKey) { endOnboarding() }
            return
        }
        // In the background, the decision waits for the next open in front.
        guard onboarding == .undecided, windowIsActive else { return }
        // A reminder tap or a widget link opens Today. The onboarding waits for the next launch with no item.
        onboarding = opensForAction ? .hidden : .shows
    }

    /// The root view calls this with the phase of its window, also at the first frame.
    func windowDidChange(isActive: Bool) {
        windowIsActive = isActive
        updateOnboarding()
    }

    /// A reminder tap or a widget link opens Today. The onboarding does not show in this process, and the flag stays
    /// unset, so the next launch with no item shows it (D104).
    func onboardingYieldsToAction() {
        opensForAction = true
        if onboarding == .shows { onboarding = .hidden }
    }

    /// "Add Item", "Later", "Skip", or a restore. The onboarding never shows again on this device.
    func endOnboarding() {
        UserDefaults.standard.set(true, forKey: Onboarding.seenKey)
        onboarding = .hidden
    }
}
