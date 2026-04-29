import SentinelCore
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

public enum ChatComposerAttachmentFactory {
    private enum Preview {
        static let jpegCompressionQuality = 0.72
        static let maxPixelSize = 224
    }

    public static func makeAttachment(from data: Data, contentType: UTType, index: Int) -> ChatComposerAttachment? {
        let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
        let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
        let filename = "photo-\(UUID().uuidString.prefix(8))-\(index + 1).\(fileExtension)"

        return .init(
            data: data,
            previewData: makePreviewData(from: data, contentType: contentType),
            filename: filename,
            mimeType: mimeType
        )
    }

    public static func makePreviewData(from data: Data, contentType: UTType, maxPixelSize: Int = 224) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        if contentType.conforms(to: .png) {
            return image.pngData()
        }
        return image.jpegData(compressionQuality: Preview.jpegCompressionQuality)
    }
}
