import AVFoundation
import SwiftUI

/// The reminder sounds of Maru Pro (D112). `docs/brand/make_sounds.py` makes the files in `App/Sounds`.
/// No value is the default sound of the system.
enum ReminderSound: String, CaseIterable, Identifiable {
    case dewdrop, petal, breeze, pebble, sunrise, lantern

    /// The choice in `UserDefaults.standard`, beside the display settings (D014). The backup does not carry it.
    static let key = "reminders.sound"

    var id: Self { self }

    /// The file in the app bundle. The system plays it for a notification (`UNNotificationSound(named:)`).
    var fileName: String { "maru-\(rawValue).caf" }

    var title: LocalizedStringResource {
        switch self {
        case .dewdrop: "Dewdrop"
        case .petal: "Petal"
        case .breeze: "Breeze"
        case .pebble: "Pebble"
        case .sunrise: "Sunrise"
        case .lantern: "Lantern"
        }
    }

    /// The user's choice. It stays when Maru Pro ends, so it comes back with Pro.
    static var chosen: ReminderSound? {
        UserDefaults.standard.string(forKey: key).flatMap(ReminderSound.init(rawValue:))
    }

    /// The sound that a reminder run gives the requests: the choice while Maru Pro is active, else the default sound.
    /// It reads the cached plan, so it runs off the main actor. Each run reads it again, so the reminders go back to the
    /// default sound at the first run after Pro ends.
    static func inUse(at now: Date = Date()) -> ReminderSound? {
        ProStore.cachedPlan(at: now) == nil ? nil : chosen
    }
}

/// Plays a sound once, when the user taps it in Settings. The preview is free (D112).
@MainActor
final class SoundPreview {
    static let shared = SoundPreview()
    private var player: AVAudioPlayer?

    func play(_ sound: ReminderSound) {
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: nil) else { return }
        // The preview plays with the ring switch on silent too, and it mixes with other audio and does not stop it.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}
