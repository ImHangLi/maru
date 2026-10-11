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

/// The live label scan (D038, docs/design.md "Scan Label").
///
/// The system scanner marks the text that it finds. The user taps the name, and the card at the bottom
/// shows it. A second tap adds a second line of the name. "Use This Name" gives the name to the edit
/// screen, where the user can change it. Nothing is saved here.
struct LabelScanView: View {
    /// Receives the name after "Use This Name".
    let use: (LabelScan) -> Void
    /// The camera stopped, for example because the user turned it off for Maru.
    let failed: () -> Void

    @Environment(\.dismiss) private var dismiss
    /// The texts that the user tapped, in the order of the taps.
    @State private var parts: [String] = []
    @State private var forms: Set<LabelForm> = []

    init(use: @escaping (LabelScan) -> Void, failed: @escaping () -> Void) {
        self.use = use
        self.failed = failed
    }

    private var name: String { LabelText.name(from: parts) }

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

    /// One decision at a time: first the prompt, then the name with its actions.
    private var card: some View {
        VStack(spacing: 12) {
            if parts.isEmpty {
                Text("Tap the name on the label")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            } else {
                Text(verbatim: name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text("Name: \(name)"))
                if parts.count > 1 {
                    ForEach(parts, id: \.self) { part in
                        let text = LabelText.clean(part)
                        Button {
                            parts.removeAll { $0 == part }
                        } label: {
                            Label {
                                Text(verbatim: text)
                            } icon: {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(Text("Remove \(text)"))
                    }
                }
                Button {
                    use(LabelScan(name: name, forms: forms))
                    dismiss()
                } label: {
                    Text("Use This Name")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button("Clear") { parts = [] }
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
        // The card grows and shrinks with the name (D030).
        .motion(.layout, value: parts)
    }

    /// A tap on a text adds it to the name. A second tap on the same text changes nothing.
    private func add(_ text: String) {
        guard !LabelText.clean(text).isEmpty, !parts.contains(text), parts.count < 4 else { return }
        parts.append(text)
        AccessibilityNotification.Announcement(String(localized: "Name: \(name)")).post()
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
