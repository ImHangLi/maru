import AVFoundation
import SwiftUI

/// PROTOTYPE (not for merge): one feature of Maru Pro, shown as a short looping clip (or a still), a title, and one line.
struct ProSlide: Identifiable {
    /// The name of the media in `App/Pro/Clips`, without the extension: `<id>.mp4` for the clip, and `still-<name>.png`
    /// for the still, with the `pro-` prefix removed. A `-dark` file, when it exists, is the media for dark mode.
    let id: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    /// The second of the clip that the still frame shows with Reduce Motion.
    let poster: Double

    static var all: [ProSlide] { [
        ProSlide(
            id: "pro-lock-screen", title: "Right on your Lock Screen",
            detail: "See dose and time without opening Maru.", poster: 4.0
        ),
        ProSlide(
            id: "pro-family", title: "Your whole family",
            detail: "People and pets, each with their own reminders.", poster: 1.0
        ),
        ProSlide(
            id: "pro-watch", title: "Record from your wrist",
            detail: "Apple Watch shows and records each dose.", poster: 4.0
        ),
        ProSlide(
            id: "pro-report", title: "Reports for your doctor",
            detail: "PDF summaries and 30-day counts.", poster: 0
        ),
        ProSlide(
            id: "pro-personalize", title: "Make Maru yours",
            detail: "App colors, icons, and reminder sounds.", poster: 0.5
        ),
    ] }
}

/// PROTOTYPE: the features of Maru Pro as a carousel with no frame. The media fades into the page on every edge, so the
/// picture above, the media, and the plans read as one page. It moves to the next slide after `slideDuration`, and the
/// user can swipe. Only the slide on the display plays. With Reduce Motion it does not move by itself, and each clip
/// shows a still frame.
struct ProCarousel: View {
    let slides: [ProSlide]
    @Binding var index: Int
    /// Stills instead of clips, for the comparison of the two variants (`-MaruPaywallStills YES`).
    var usesStills = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var captionHeight = 40
    /// The width of the carousel. The media and the caption take their height from it.
    @State private var width: CGFloat = 402
    @State private var startedAt = Date.now
    /// The slide that the scroll view shows. A swipe changes it, and an advance or a tap on a bar sets it.
    @State private var scrolled: Int?

    static let slideDuration: TimeInterval = 5
    /// The shape of the media on the page. The files are 720 by 640 pixels, and the page crops a little at the sides,
    /// where the media fades anyway.
    static let mediaAspect: CGFloat = 1.2

    private var autoAdvances: Bool { !reduceMotion && scenePhase == .active }

    var body: some View {
        VStack(spacing: 6) {
            // A paging scroll view, not a page `TabView`: the page `TabView` draws an opaque background over the fade of
            // the picture above.
            ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(slides.indices, id: \.self) { slideIndex in
                            page(slides[slideIndex], isCurrent: slideIndex == index, width: width)
                                .frame(width: width)
                                .id(slideIndex)
                        }
                    }
                    .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolled)
            // The scroll view clips its pages, so it holds the media and the caption under it.
            .frame(height: width / Self.mediaAspect + captionHeight)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            indicator
        }
        .onAppear { scrolled = index }
        .onChange(of: scrolled) { _, value in if let value, value != index { index = value } }
        .onChange(of: index) { _, value in
            if scrolled != value { withAnimation(reduceMotion ? nil : .smooth(duration: 0.5)) { scrolled = value } }
        }
        // A swipe or an advance starts the time of the new slide again.
        .task(id: "\(index)-\(autoAdvances)") {
            startedAt = .now
            guard autoAdvances else { return }
            try? await Task.sleep(for: .seconds(Self.slideDuration))
            guard !Task.isCancelled else { return }
            index = (index + 1) % slides.count
        }
    }

    /// The media with soft edges, and close under it the title and the line in quiet type.
    private func page(_ slide: ProSlide, isCurrent: Bool, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            media(slide, isCurrent: isCurrent)
                .frame(width: width, height: width / Self.mediaAspect)
                .clipped()
                .mask { EdgeFade() }
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                Text(slide.title).font(.subheadline.weight(.semibold))
                Text(slide.detail).font(.footnote).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.horizontal, 20)
            .fixedSize(horizontal: false, vertical: true)
            // The caption sits close under the media, where its bottom fade ends.
            .padding(.top, -4)
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func media(_ slide: ProSlide, isCurrent: Bool) -> some View {
        if usesStills {
            if let image = Self.still(slide.id, dark: colorScheme == .dark) {
                Image(uiImage: image).resizable().scaledToFill()
            }
        } else {
            LoopingClip(
                url: Self.clipURL(slide.id, dark: colorScheme == .dark),
                isPlaying: isCurrent && !reduceMotion, poster: slide.poster
            )
            // A new scheme loads the other clip.
            .id(colorScheme)
        }
    }

    /// The dark clip when one exists, else the light clip.
    private static func clipURL(_ name: String, dark: Bool) -> URL? {
        (dark ? Bundle.main.url(forResource: "\(name)-dark", withExtension: "mp4") : nil)
            ?? Bundle.main.url(forResource: name, withExtension: "mp4")
    }

    private static func still(_ name: String, dark: Bool) -> UIImage? {
        let base = "still-\(name.replacingOccurrences(of: "pro-", with: ""))"
        let url = (dark ? Bundle.main.url(forResource: "\(base)-dark", withExtension: "png") : nil)
            ?? Bundle.main.url(forResource: base, withExtension: "png")
        return url.flatMap { UIImage(contentsOfFile: $0.path) }
    }

    /// One short bar per slide, like Stories: the slides before are full, the current one fills over its time, and the
    /// slides after are empty. With Reduce Motion the current bar is full. A tap on a bar opens its slide.
    private var indicator: some View {
        TimelineView(.animation(paused: !autoAdvances)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt) / Self.slideDuration
            HStack(spacing: 5) {
                ForEach(slides.indices, id: \.self) { slideIndex in
                    let fill: Double = slideIndex < index ? 1
                        : slideIndex > index ? 0
                        : autoAdvances ? min(max(elapsed, 0), 1) : 1
                    Capsule()
                        .fill(Color.primary.opacity(0.12))
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.primary.opacity(0.55))
                                    .frame(width: proxy.size.width * fill)
                            }
                        }
                        .clipShape(.capsule)
                        .frame(width: 22, height: 3)
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                        .onTapGesture {
                            index = slideIndex
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

/// An alpha mask that fades every edge with an eased curve (smootherstep): 30 percent at the top, where the picture above
/// fades into the page, 18 percent at the bottom, and 9 percent at the sides. The media then has no visible edge on the page background.
private struct EdgeFade: View {
    /// `top` is the start edge, and `bottom` the end edge, as fractions of the length.
    private static func stops(top: Double, bottom: Double) -> [Gradient.Stop] {
        let ramp = (0...8).map { step -> (t: Double, opacity: Double) in
            let t = Double(step) / 8
            return (t, t * t * t * (t * (t * 6 - 15) + 10))
        }
        return ramp.map { Gradient.Stop(color: .black.opacity($0.opacity), location: $0.t * top) }
            + ramp.reversed().map { Gradient.Stop(color: .black.opacity($0.opacity), location: 1 - $0.t * bottom) }
    }

    var body: some View {
        LinearGradient(stops: Self.stops(top: 0.3, bottom: 0.18), startPoint: .top, endPoint: .bottom)
            .mask { LinearGradient(stops: Self.stops(top: 0.09, bottom: 0.09), startPoint: .leading, endPoint: .trailing) }
    }
}

/// A muted clip that loops with `AVPlayerLooper`. The clips have no audio track, so they do not touch the audio session
/// and do not stop music. A clip that is not on the display pauses on its still frame.
private struct LoopingClip: UIViewRepresentable {
    let url: URL?
    let isPlaying: Bool
    let poster: Double

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

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

        init(url: URL?) {
            player.isMuted = true
            player.allowsExternalPlayback = false
            player.preventsDisplaySleepDuringVideoPlayback = false
            if let url {
                looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            }
        }

        func update(isPlaying: Bool, poster: Double) {
            guard isPlaying != wasPlaying else { return }
            wasPlaying = isPlaying
            if isPlaying {
                // The clip plays on from its still frame, so the swipe shows no jump.
                player.play()
            } else {
                player.pause()
                player.seek(to: CMTime(seconds: poster, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
}
