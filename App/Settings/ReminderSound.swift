import AVFoundation
import SwiftUI

/// The reminder sounds of Maru Pro (D112, replaced by D120). The files in `App/Sounds` are CC0 sounds from other
/// authors (`docs/third-party-licenses.md`). No value is the default sound of the system.
enum ReminderSound: String, CaseIterable, Identifiable {
    case risingChime = "rising-chime"
    case marimba = "marimba-hello"
    case softBell = "soft-bell"
    case glass = "glass-ting"
    case chimeBars = "chime-bars"
    case handBell = "hand-bell"
    case musicBox = "music-box"
    case synthBell = "synth-bell"

    /// The choice in `UserDefaults.standard`, beside the display settings (D014). The backup does not carry it.
    static let key = "reminders.sound"

    var id: Self { self }

    /// The file in the app bundle. The system plays it for a notification (`UNNotificationSound(named:)`).
    var fileName: String { "maru-\(rawValue).caf" }

    var title: LocalizedStringResource {
        switch self {
        case .risingChime: "Rising Chime"
        case .marimba: "Marimba"
        case .softBell: "Soft Bell"
        case .glass: "Glass"
        case .chimeBars: "Chime Bars"
        case .handBell: "Hand Bell"
        case .musicBox: "Music Box"
        case .synthBell: "Synth Bell"
        }
    }

    /// The user's choice. It stays when Maru Pro ends, so it comes back with Pro. A stored name that no sound has
    /// (a sound that an earlier build had, D112) reads as no choice, so it means the default sound (D120).
    static var chosen: ReminderSound? {
        UserDefaults.standard.string(forKey: key).flatMap(ReminderSound.init(rawValue:))
    }

    /// The sound that a reminder run gives the requests: the choice while Maru Pro is active, else the default sound.
    /// It reads the cached plan, so it runs off the main actor. Each run reads it again, and each change of Pro starts a
    /// run (`AppModel.proDidChange`), so the reminders follow a refund, an expiry, or a restore.
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
