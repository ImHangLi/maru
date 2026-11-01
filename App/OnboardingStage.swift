import MaruCore
import SwiftUI

/// The moving picture of an onboarding page (D145): a phone with a picture of the product, on a slow loop. It starts
/// wide, zooms in to the part that matters, holds, and zooms out. Each frame draws again at its own scale, so the text
/// stays sharp, and the app needs no video or image file.
///
/// The picture is decoration with sample words. It writes nothing, and VoiceOver reads the title and the line of the page.
struct OnboardingStage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DisplaySetting.appColor) private var appColor = ItemColor.pink
    let page: OnboardingPage
    let isCurrent: Bool
    /// The status bar above the picture. The wide view of the phone stays under it.
    let topInset: CGFloat
    @State private var isClose = false
    @State private var step = 0

    var body: some View {
        // With Reduce Motion the page shows one still picture at the close view.
        let script = page.script
        GeometryReader { proxy in
            let area = CGRect(x: 0, y: topInset, width: proxy.size.width, height: proxy.size.height - topInset)
            OnboardingPhone(page: page, step: reduceMotion ? script.stillStep : step)
                .modifier(OnboardingCamera(zoom: reduceMotion || isClose ? 1 : 0, stage: proxy.size, area: area, focus: script.focus))
                .frame(width: proxy.size.width, height: proxy.size.height)
                // Inside this group the scale is part of the drawing, so the text stays sharp at each scale.
                .drawingGroup()
                .mask { fade(height: proxy.size.height) }
        }
        .background(alignment: .top) {
            HeaderWash.gradient(appColor)
        }
        .clipped()
        .accessibilityHidden(true)
        .task(id: isCurrent && !reduceMotion) { await play(script) }
    }

    /// The picture fades out under the status bar and above the words, so it has no hard edge.
    private func fade(height: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: topInset * 0.7 / height),
                .init(color: .black, location: (topInset + 8) / height),
                .init(color: .black, location: 0.9),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// The loop runs only for the page on the display. A page that leaves goes back to the wide view.
    private func play(_ script: OnboardingScript) async {
        guard isCurrent, !reduceMotion else {
            withMotion(.camera) { isClose = false }
            step = 0
            return
        }
        while !Task.isCancelled {
            for beat in script.beats {
                try? await Task.sleep(for: .seconds(beat.wait))
                guard !Task.isCancelled else { return }
                switch beat.change {
                case let .close(close): withMotion(.camera) { isClose = close }
                case let .step(next): withMotion(.layout) { step = next }
                }
            }
        }
    }
}

/// The timing of one picture.
struct OnboardingScript {
    enum Change {
        case close(Bool)
        case step(Int)
    }

    /// `wait` is the time in seconds after the beat before it.
    typealias Beat = (wait: Double, change: Change)

    /// The part of the phone that the close view shows, in the points of `OnboardingPhone.size`.
    let focus: CGRect
    let beats: [Beat]
    /// The step of the still picture for Reduce Motion.
    let stillStep: Int
}

/// Moves and scales the phone from the wide view to the close view. `zoom` is 0 for the wide view and 1 for the close view.
/// The phone moves on a straight line to the focus, as a camera does.
nonisolated private struct OnboardingCamera: ViewModifier, Animatable {
    var zoom: Double
    let stage: CGSize
    /// The part of the stage under the status bar.
    let area: CGRect
    let focus: CGRect

    var animatableData: Double {
        get { zoom }
        set { zoom = newValue }
    }

    func body(content: Content) -> some View {
        let phone = OnboardingPhone.size
        // The wide view shows the top of the phone. The fade of the stage hides the last part of it.
        let wide = min(area.height * 1.16 / phone.height, (area.width - 56) / phone.width)
        let wideCenter = CGPoint(x: area.midX, y: area.minY + 12 + phone.height * wide / 2)
        // The close view shows the whole focus in the middle of the area. The limit keeps the edges of the phone on an iPad.
        let close = max(min(area.width / focus.width, area.height * 0.9 / focus.height, wide * 1.8), wide * 1.1)
        let closeCenter = CGPoint(
            x: area.midX - (focus.midX - phone.width / 2) * close,
            y: area.midY - (focus.midY - phone.height / 2) * close
        )
        let scale = wide * pow(close / wide, zoom)
        let progress = (scale - wide) / (close - wide)
        content
            .scaleEffect(scale)
            .offset(
                x: wideCenter.x + (closeCenter.x - wideCenter.x) * progress - stage.width / 2,
                y: wideCenter.y + (closeCenter.y - wideCenter.y) * progress - stage.height / 2
            )
    }
}
