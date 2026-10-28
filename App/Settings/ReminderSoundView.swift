import SwiftUI

/// "Reminder Sound" in Settings (D112): "Default" and the sounds of Maru Pro. Every sound has a free preview. A free
/// user who chooses a sound other than "Default" gets the paywall.
struct ReminderSoundView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Form {
            Section {
                row(nil)
                ForEach(ReminderSound.allCases) { row($0) }
            } footer: {
                if !model.pro.isPro {
                    Text("Listen to each sound for free. Maru Pro lets you choose one.")
                }
            }
        }
        .navigationTitle("Reminder Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { SoundPreview.shared.stop() }
    }

    private func row(_ sound: ReminderSound?) -> some View {
        // A free user sees the default sound as chosen, because the reminders use it.
        let isChosen = model.reminderSound == sound
        return HStack {
            Button {
                // A choice plays the sound once. A free user gets the paywall and can still use the play button.
                if let sound, model.pro.isPro { SoundPreview.shared.play(sound) }
                model.chooseReminderSound(sound)
            } label: {
                HStack {
                    if let sound { Text(sound.title) } else { Text("Default") }
                    Spacer()
                    if isChosen {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.primary)
            .accessibilityAddTraits(isChosen ? .isSelected : [])
            if let sound {
                Button {
                    SoundPreview.shared.play(sound)
                } label: {
                    Label {
                        Text("Play \(String(localized: sound.title))")
                    } icon: {
                        Image(systemName: "play.circle")
                    }
                    .labelStyle(.iconOnly)
                    .imageScale(.large)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
