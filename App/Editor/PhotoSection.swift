import AVFoundation
import MaruCore
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

/// How the item looks: the current icon or photo, the form and color choices, and the optional photo (spec 5.1,
/// D056, D073). The photo choice is beside the form, because both choose the icon. The photo replaces the form
/// icon where the item shows it. The form icon stays as the fallback (T32).
struct LookSection<Choices: View>: View {
    @Binding var state: PhotoState
    /// The photo file of the stored item, if it has one.
    let storedReference: String?
    let form: ItemForm
    let color: ItemColor
    /// The form and color pickers.
    @ViewBuilder let choices: Choices

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
            preview
            choices
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo")
                    .labelStyle(RowLabelStyle())
            }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo", systemImage: "camera", action: startCamera)
                    .labelStyle(RowLabelStyle())
                    .fullScreenCover(isPresented: $takesPhoto) {
                        CameraPicker { image in
                            takesPhoto = false
                            if let image { state.request = PhotoRequest(source: .camera(image)) }
                        }
                        .ignoresSafeArea()
                    }
                    .alert("Camera Is Off", isPresented: $cameraIsOff) {
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

    /// The icon as the lists show it: the photo, else the form icon in the item color.
    private var preview: some View {
        HStack {
            Spacer()
            if case let .replaced(choice) = state.edit {
                Image(uiImage: choice.chosen.preview)
                    .resizable()
                    .scaledToFit()
                    .frame(width: previewSide, height: previewSide)
                    .clipShape(RoundedRectangle(cornerRadius: previewSide / 5, style: .continuous))
                    .accessibilityLabel(Text("Photo"))
            } else if hasPhoto {
                ItemPhotoView(reference: storedReference, side: previewSide) { formIcon }
                    .accessibilityLabel(Text("Photo"))
            } else {
                // The form picker under it names the form, so VoiceOver reads no image name.
                formIcon
                    .accessibilityHidden(true)
            }
            Spacer()
        }
    }

    private var formIcon: some View {
        form.image
            .resizable()
            .scaledToFit()
            .padding(previewSide / 8)
            .frame(width: previewSide, height: previewSide)
            .foregroundStyle(color.color)
    }

    /// The system asks for the camera at the first tap. A camera that is off gets one sentence and a button
    /// to Settings (spec 2.2).
    private func startCamera() {
        Task {
            switch await CameraPicker.access() {
            case true?: takesPhoto = true
            case false?: cameraIsOff = true
            case nil: break
            }
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
struct CameraPicker: UIViewControllerRepresentable {
    /// Gives the photo, or `nil` when the user cancels. The caller closes the camera.
    let done: (UIImage?) -> Void

    /// The system asks for the camera at the first tap. `true` when Maru may use it, `false` when the camera is off for Maru, and
    /// `nil` when the user said no to the question just now.
    static func access() async -> Bool? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video) ? true : nil
        default: false
        }
    }

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
