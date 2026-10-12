import AVFoundation
import PhotosUI
import SwiftUI

/// What the user chose for the photo on the edit screen.
struct PhotoChoice {
    /// The plain crop (spec 5.2). It is always there, so Save never waits for the background removal.
    var crop: PhotoImage
    /// The subject with a transparent background. It comes later, and only when Vision finds one subject (T29).
    var cutout: PhotoImage?
    var usesCutout: Bool

    var chosen: PhotoImage { usesCutout ? cutout ?? crop : crop }
}

/// One photo that the user picked. A new pick replaces the one before it, and its task cancels the old task.
struct PhotoRequest {
    let id = UUID()
    /// The task takes it out when it starts, so the state does not hold a large camera image while the user edits.
    var source: PhotoSource?
}

/// The photo state of one open edit screen (D056).
///
/// It is not part of the draft file: the draft keeps text and choices, and the photo is chosen again after
/// the app stops. The state lives and dies with the screen, so a late result of the background removal can not
/// reach another item or a closed screen (T30).
struct PhotoState {
    enum Edit {
        case unchanged
        case removed
        case replaced(PhotoChoice)
    }

    enum Step {
        case idle
        case reading
        case removingBackground
        /// Vision found no subject or more than one. The crop stays (T29).
        case noSubject
        case unreadable
    }

    var edit = Edit.unchanged
    var step = Step.idle
    var request: PhotoRequest?

    var isChanged: Bool {
        if case .unchanged = edit { false } else { true }
    }

    var hasCutout: Bool {
        if case let .replaced(choice) = edit { choice.cutout != nil } else { false }
    }

    var usesCutout: Bool {
        get { if case let .replaced(choice) = edit { choice.usesCutout } else { false } }
        set {
            guard case var .replaced(choice) = edit else { return }
            choice.usesCutout = newValue
            edit = .replaced(choice)
        }
    }
}

extension View {
    /// Runs the work for the latest photo request of `state`. A new request or the end of the screen cancels it.
    func photoWork(_ state: Binding<PhotoState>) -> some View {
        modifier(PhotoWork(state: state))
    }
}

private struct PhotoWork: ViewModifier {
    @Binding var state: PhotoState

    func body(content: Content) -> some View {
        content.task(id: state.request?.id) { await run() }
    }

    /// The crop comes first and fills the state at once. The background removal follows and replaces the
    /// crop only when it finds one subject. Each step checks the cancel, so a result of a stopped request
    /// writes nothing.
    private func run() async {
        guard let source = state.request?.source else { return }
        state.request?.source = nil
        state.step = .reading
        guard let crop = await PhotoProcessor.crop(source) else {
            if !Task.isCancelled { state.step = .unreadable }
            return
        }
        guard !Task.isCancelled else { return }
        state.edit = .replaced(PhotoChoice(crop: crop.image, cutout: nil, usesCutout: false))
        state.step = .removingBackground
        let cutout = await PhotoProcessor.cutout(of: crop)
        guard !Task.isCancelled else { return }
        if let cutout {
            state.edit = .replaced(PhotoChoice(crop: crop.image, cutout: cutout, usesCutout: true))
            state.step = .idle
        } else {
            state.step = .noSubject
        }
    }
}

/// The optional photo of the item (spec 5.1, D056): a photo from the library or from the camera. The photo
/// replaces the form icon where the item shows it. The form icon stays as the fallback (T32).
struct PhotoSection: View {
    @Binding var state: PhotoState
    /// The photo file of the stored item, if it has one.
    let storedReference: String?

    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .body) private var previewSide = 56
    @State private var pickerItem: PhotosPickerItem?
    @State private var takesPhoto = false
    @State private var cameraIsOff = false

    private var hasPhoto: Bool {
        switch state.edit {
        case .unchanged: storedReference != nil
        case .removed: false
        case .replaced: true
        }
    }

    var body: some View {
        Section {
            if hasPhoto {
                preview
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera", action: startCamera)
                    .fullScreenCover(isPresented: $takesPhoto) {
                        CameraPicker { image in
                            takesPhoto = false
                            if let image { state.request = PhotoRequest(source: .camera(image)) }
                        }
                        .ignoresSafeArea()
                    }
                    .alert("Maru Can’t Use the Camera", isPresented: $cameraIsOff) {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("To take a photo, allow the camera for Maru in Settings.")
                    }
            }
            if state.hasCutout {
                Toggle("Remove Background", isOn: $state.usesCutout)
            }
            if state.step == .reading || state.step == .removingBackground {
                HStack(spacing: 12) {
                    ProgressView()
                    Group {
                        if state.step == .reading { Text("Reading the photo…") } else { Text("Removing the background…") }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            if hasPhoto {
                Button("Remove Photo", role: .destructive, action: remove)
            }
        } header: {
            Text("Photo (Optional)")
        } footer: {
            switch state.step {
            case .noSubject: Text("Maru found no single subject, so the photo stays as it is.")
            case .unreadable: Text("Maru couldn’t read this photo.")
            default: EmptyView()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            state.request = PhotoRequest(source: .library(item))
            pickerItem = nil
        }
    }

    @ViewBuilder private var preview: some View {
        HStack {
            if case let .replaced(choice) = state.edit {
                Image(uiImage: choice.chosen.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSide, height: previewSide)
                    .clipShape(RoundedRectangle(cornerRadius: previewSide / 5, style: .continuous))
                    .accessibilityLabel(Text("Photo"))
            } else {
                ItemPhotoView(reference: storedReference, side: previewSide) { EmptyView() }
                    .accessibilityLabel(Text("Photo"))
            }
            Spacer()
        }
    }

    /// The system asks for the camera at the first tap. A camera that is off gets one sentence and a button
    /// to Settings (spec 2.2).
    private func startCamera() {
        Task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: break
            case .notDetermined: guard await AVCaptureDevice.requestAccess(for: .video) else { return }
            default:
                cameraIsOff = true
                return
            }
            takesPhoto = true
        }
    }

    /// A stored photo is removed when the user saves. A new photo that is not saved yet is dropped at once.
    private func remove() {
        state.request = nil
        state.step = .idle
        state.edit = storedReference == nil ? .unchanged : .removed
    }
}

/// The system camera for one photo. The system keeps the photo only in memory and gives it to Maru. It is not
/// saved to the photo library.
private struct CameraPicker: UIViewControllerRepresentable {
    /// Gives the photo, or `nil` when the user cancels. The caller closes the camera.
    let done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.done(nil)
        }
    }
}
