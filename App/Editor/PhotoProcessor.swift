import CoreImage
import ImageIO
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Vision

/// Where a new photo comes from.
enum PhotoSource: @unchecked Sendable {
    case library(PhotosPickerItem)
    case camera(UIImage)
}

/// One image as it is stored: the file bytes, and the image that the edit screen shows.
struct PhotoImage: @unchecked Sendable {
    let data: Data
    let fileExtension: String
    let preview: UIImage
}

/// The first result of a new photo: the plain crop, and the scaled image that the background removal reads.
struct PhotoCrop: @unchecked Sendable {
    let image: PhotoImage
    let scaled: CGImage
}

/// The steps from a chosen photo to the files that the store keeps (spec 5.2, D056).
///
/// Every step runs off the main actor and checks for cancellation. The cutout is a separate step, so Save
/// never waits for it: the crop is ready first. The images carry no metadata. A decoded image has only pixels,
/// and the encoder gets no properties, so the EXIF data and the location do not reach the file (T31).
/// The original image is never kept, only the scaled image (T31).
enum PhotoProcessor {
    /// Reads the photo, scales it to at most `ItemPhotos.maxPixel` on the longest side, applies its rotation,
    /// and crops the middle square. `nil` when the source is not an image.
    static func crop(_ source: PhotoSource) async -> PhotoCrop? {
        let scale: @Sendable (Data) -> CGImage? = { data in
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
            else { return nil }
            // The thumbnail is cut from the stream, so the full image is never decoded.
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: ItemPhotos.maxPixel,
            ]
            return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
        }
        switch source {
        case let .library(item):
            guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
            return await offMain(.userInitiated) { scale(data).flatMap(makeCrop) }
        case let .camera(image):
            return await offMain(.userInitiated) { scaled(image).flatMap(makeCrop) }
        }
    }

    /// Lifts the one foreground subject of the image, with a transparent background (T29). `nil` when Vision
    /// fails, finds no subject, or finds more than one: Maru then keeps the crop and picks no subject itself.
    static func cutout(of crop: PhotoCrop) async -> PhotoImage? {
        await offMain(.utility) {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: crop.scaled)
            guard (try? handler.perform([request])) != nil,
                  let result = request.results?.first,
                  result.allInstances.count == 1,
                  !Task.isCancelled,
                  let buffer = try? result.generateMaskedImage(
                      ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true
                  )
            else { return nil }
            let image = CIImage(cvPixelBuffer: buffer)
            guard let cutout = CIContext().createCGImage(image, from: image.extent) else { return nil }
            return encode(cutout, as: .png, fileExtension: "png")
        }
    }

    private static func makeCrop(_ scaled: CGImage) -> PhotoCrop? {
        let side = min(scaled.width, scaled.height)
        let square = CGRect(x: (scaled.width - side) / 2, y: (scaled.height - side) / 2, width: side, height: side)
        guard let cropped = scaled.cropping(to: square),
              let image = encode(cropped, as: .jpeg, fileExtension: "jpg") else { return nil }
        return PhotoCrop(image: image, scaled: scaled)
    }

    /// A camera image: it is drawn at the target size, which also applies its rotation.
    private static func scaled(_ image: UIImage) -> CGImage? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let factor = min(1, CGFloat(ItemPhotos.maxPixel) / longest)
        let size = CGSize(width: (image.size.width * factor).rounded(), height: (image.size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private static func encode(_ image: CGImage, as type: UTType, fileExtension: String) -> PhotoImage? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        // No metadata is added: the properties are only the quality.
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.85]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return PhotoImage(data: data as Data, fileExtension: fileExtension, preview: UIImage(cgImage: image))
    }

    /// Runs `work` in a task off the main actor. A cancel of the caller cancels the work too.
    private static func offMain<T: Sendable>(
        _ priority: TaskPriority,
        _ work: @escaping @Sendable () -> T?
    ) async -> T? {
        let task = Task.detached(priority: priority) { work() }
        return await withTaskCancellationHandler { await task.value } onCancel: { task.cancel() }
    }
}
