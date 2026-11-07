import AVFoundation
import SwiftUI

/// PROTOTYPE (not for merge): one feature of Maru Pro, shown as a short looping clip with a title and one line.
struct ProSlide: Identifiable {
    /// The name of the clip in `App/Pro/Clips`, without the extension.
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    /// The second of the clip that the still shows with Reduce Motion.
    let poster: Double

    static var all: [ProSlide] { [
        ProSlide(
            id: "pro-lock-screen", title: "Right on your Lock Screen",
            detail: "See dose and time without opening Maru.", poster: 0.5
        ),
        ProSlide(
            id: "pro-family", title: "Your whole family",
            detail: "People and pets, each with their own reminders.", poster: 1.6
        ),
        ProSlide(
            id: "pro-watch", title: "Record from your wrist",
            detail: "Apple Watch shows and records each dose.", poster: 4.2
        ),
        ProSlide(
            id: "pro-report", title: "Reports for your doctor",
            detail: "PDF summaries and 30-day counts.", poster: 0
        ),
        ProSlide(
            id: "pro-icons", title: "Icons for your Home Screen",
            detail: "Ceramic and classic app icons.", poster: 1.0
        ),
        ProSlide(
            id: "pro-sounds", title: "Reminder sounds",
            detail: "Eight calm sounds for your reminders.", poster: 1.0
        ),
        ProSlide(
            id: "pro-color", title: "Make Maru yours",
            detail: "Pick the color of the whole app.", poster: 0.9
        ),
    ] }
}

/// PROTOTYPE: the features of Maru Pro as a carousel. It moves to the next slide after `slideDuration`, and the user can
/// swipe. Only the slide on the display plays. With Reduce Motion it does not move by itself, and each clip shows a still.
struct ProCarousel: View {
    let slides: [ProSlide]
    @Binding var index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .title2) private var textHeight = 58
    @State private var startedAt = Date.now

    static let slideDuration: TimeInterval = 5
    /// The height of the clip.
    let clipHeight: CGFloat

    private var autoAdvances: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        VStack(spacing: 4) {
            TabView(selection: $index) {
                ForEach(slides.indices, id: \.self) { slideIndex in
                    page(slides[slideIndex], isCurrent: slideIndex == index)
                        .tag(slideIndex)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: clipHeight + 16 + textHeight)
            indicator
        }
        // A swipe or an advance starts the time of the new slide again.
        .task(id: "\(index)-\(autoAdvances)") {
            startedAt = .now
            guard autoAdvances else { return }
            try? await Task.sleep(for: .seconds(Self.slideDuration))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.45)) { index = (index + 1) % slides.count }
        }
    }

    private func page(_ slide: ProSlide, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LoopingClip(name: slide.id, isPlaying: isCurrent && !reduceMotion, poster: slide.poster)
                .frame(maxWidth: .infinity)
                .frame(height: clipHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(slide.title).font(.title2.bold())
                Text(slide.detail).font(.body).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    /// One short bar per slide, like Stories: the slides before are full, the current one fills over its time, and the
    /// slides after are empty. With Reduce Motion the current bar is full. A tap on a bar opens its slide.
    private var indicator: some View {
        TimelineView(.animation(paused: !autoAdvances)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt) / Self.slideDuration
            HStack(spacing: 6) {
                ForEach(slides.indices, id: \.self) { slideIndex in
                    let fill: Double = slideIndex < index ? 1
                        : slideIndex > index ? 0
                        : autoAdvances ? min(max(elapsed, 0), 1) : 1
                    Capsule()
                        .fill(Color.primary.opacity(0.14))
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.primary.opacity(0.75))
                                    .frame(width: proxy.size.width * fill)
                            }
                        }
                        .clipShape(.capsule)
                        .frame(width: 26, height: 4)
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { index = slideIndex }
                        }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Feature \(index + 1) of \(slides.count)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: index = min(index + 1, slides.count - 1)
            case .decrement: index = max(index - 1, 0)
            @unknown default: break
            }
        }
    }
}

/// A muted clip that loops with `AVPlayerLooper`. The clips have no audio track, so they do not touch the audio session
/// and do not stop music. A clip that is not on the display pauses on its still.
private struct LoopingClip: UIViewRepresentable {
    let name: String
    let isPlaying: Bool
    let poster: Double

    func makeCoordinator() -> Coordinator { Coordinator(name: name) }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = context.coordinator.player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PlayerView, context: Context) {
        context.coordinator.update(isPlaying: isPlaying, poster: poster)
    }

    static func dismantleUIView(_ view: PlayerView, coordinator: Coordinator) {
        coordinator.player.pause()
    }

    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    @MainActor
    final class Coordinator {
        let player = AVQueuePlayer()
        private var looper: AVPlayerLooper?
        private var wasPlaying: Bool?

        init(name: String) {
            player.isMuted = true
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            }
        }

        func update(isPlaying: Bool, poster: Double) {
            guard isPlaying != wasPlaying else { return }
            wasPlaying = isPlaying
            if isPlaying {
                // The clip plays on from its still, so the swipe shows no jump.
                player.play()
            } else {
                player.pause()
                // The still of Reduce Motion, and the first look of a slide that comes next.
                player.seek(to: CMTime(seconds: poster, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
}
