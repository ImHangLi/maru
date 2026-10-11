import MaruCore
import SwiftUI
import UIKit
import VisionKit

/// What the label scan gives to the edit screen: the name that the user chose, and the form words that
/// the camera saw. No image and no other text leaves the scan (D038).
struct LabelScan {
    let name: String
    let forms: Set<LabelForm>
}

/// The live label scan (D038, D042, docs/design.md "Scan Label").
///
/// The system scanner marks the text that it finds. The user taps the name, and the card at the bottom
/// shows its words. The words that look like the name are chosen, and a tap on a word adds or removes it.
/// A second tap on the label adds a second line of the name. The field under the words shows the name, and
/// the user can type in it. "Use This Name" gives the field text to the edit screen. Nothing is saved here.
struct LabelScanView: View {
    /// Receives the name after "Use This Name".
    let use: (LabelScan) -> Void
    /// The camera stopped, for example because the user turned it off for Maru.
    let failed: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// The texts that the user tapped, in the order of the taps.
    @State private var parts: [String] = []
    /// The words of the tapped texts: the texts in the order of the taps, the words in reading order.
    @State private var words: [LabelWord] = []
    /// The name in the field. A change of the chosen words sets it again, also after the user typed.
    @State private var name = ""
    @State private var forms: Set<LabelForm> = []

    init(use: @escaping (LabelScan) -> Void, failed: @escaping () -> Void) {
        self.use = use
        self.failed = failed
    }

    private var typedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LabelScanner(tap: add, see: { forms.formUnion($0) }, failed: failed)
                    .ignoresSafeArea(edges: .bottom)
                card
            }
            .navigationTitle("Scan Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// One decision at a time: first the prompt, then the words, the name, and its actions.
    private var card: some View {
        VStack(spacing: 12) {
            if parts.isEmpty {
                Text("Tap the name on the label")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Maru reads only the name.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                WordFlow(spacing: 8) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        Toggle(word.text, isOn: chosen(index))
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .accessibilityAddTraits(word.isChosen ? .isSelected : [])
                            .motion(.state, value: word.isChosen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Tap a word to add or remove it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("Name", text: $name)
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                Button {
                    use(LabelScan(name: typedName, forms: forms))
                    dismiss()
                } label: {
                    Text("Use This Name")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(typedName.isEmpty)
                Button("Clear", action: clear)
                    .padding(.vertical, 4)
                Text("Tap more text to add it to the name.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        // The card grows and shrinks with the words (D030).
        .motion(.layout, value: parts)
    }

    /// A tap on a word adds it to the name or removes it. The field then shows the chosen words again.
    private func chosen(_ index: Int) -> Binding<Bool> {
        Binding {
            words.indices.contains(index) && words[index].isChosen
        } set: { isChosen in
            guard words.indices.contains(index) else { return }
            words[index].isChosen = isChosen
            name = LabelText.name(from: words)
        }
    }

    /// A tap on a text adds its words after the words on the card. A second tap on the same text changes
    /// nothing.
    private func add(_ text: String) {
        let new = LabelText.words(in: text)
        guard !new.isEmpty, !parts.contains(text), parts.count < 4 else { return }
        parts.append(text)
        words += new
        name = LabelText.name(from: words)
        AccessibilityNotification.Announcement(String(localized: "Name: \(name)")).post()
    }

    private func clear() {
        parts = []
        words = []
        name = ""
    }
}

/// Puts the words in rows from the leading edge, as text wraps. A word wider than the card wraps in its
/// own row. SwiftUI has no wrapping layout for iOS 17 (D042).
private struct WordFlow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = arrange(width: bounds.width, subviews: subviews).frames
        for (subview, frame) in zip(subviews, frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var point = CGPoint.zero
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if point.x > 0, point.x + size.width > width {
                point = CGPoint(x: 0, y: point.y + rowHeight + spacing)
                rowHeight = 0
            }
            frames.append(CGRect(origin: point, size: size))
            widest = max(widest, point.x + size.width)
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, CGSize(width: widest, height: point.y + rowHeight))
    }
}

/// The system data scanner in SwiftUI. It is a kept wrapper (D026, D038): VisionKit has no SwiftUI view
/// for the live scanner.
private struct LabelScanner: UIViewControllerRepresentable {
    /// The transcript of the text that the user tapped.
    let tap: (String) -> Void
    /// The form words in the text that the camera found. The text itself stays in the scanner.
    let see: (Set<LabelForm>) -> Void
    let failed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> ScannerHost {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return ScannerHost(scanner: scanner, coordinator: context.coordinator)
    }

    func updateUIViewController(_ host: ScannerHost, context: Context) {
        context.coordinator.parent = self
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: LabelScanner

        init(_ parent: LabelScanner) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case let .text(text) = item { parent.tap(text.transcript) }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            var forms: Set<LabelForm> = []
            for case let .text(text) in addedItems { forms.formUnion(LabelText.forms(in: text.transcript)) }
            if !forms.isEmpty { parent.see(forms) }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            parent.failed()
        }
    }
}

/// Holds the scanner as a child, so the scan starts after the view shows and stops when the view goes.
private final class ScannerHost: UIViewController {
    private let scanner: DataScannerViewController
    private let coordinator: LabelScanner.Coordinator

    init(scanner: DataScannerViewController, coordinator: LabelScanner.Coordinator) {
        self.scanner = scanner
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not in use")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
        NotificationCenter.default.addObserver(
            self, selector: #selector(start), name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        scanner.stopScanning()
    }

    @objc private func start() {
        guard view.window != nil, !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            coordinator.parent.failed()
        }
    }
}
