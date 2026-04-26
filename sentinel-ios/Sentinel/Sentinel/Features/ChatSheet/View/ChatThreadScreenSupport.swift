import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension ChatThreadScreenView {
    private enum ComposerPreview {
        static let maxPixelSize = 224
        static let jpegCompressionQuality = 0.72
    }

    func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }
    }

    func makeComposerAttachment(from item: PhotosPickerItem, index: Int) async -> ChatComposerAttachment? {
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else { return nil }

        let contentType = item.supportedContentTypes.first ?? .png
        let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
        let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
        let filename = "photo-\(UUID().uuidString.prefix(8))-\(index + 1).\(fileExtension)"

        return .init(
            data: data,
            previewData: makeComposerPreviewData(from: data, contentType: contentType),
            filename: filename,
            mimeType: mimeType
        )
    }

    private func makeComposerPreviewData(from data: Data, contentType: UTType) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: ComposerPreview.maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        #if canImport(UIKit)
        let image = UIImage(cgImage: cgImage)
        if contentType.conforms(to: .png) {
            return image.pngData()
        }
        return image.jpegData(compressionQuality: ComposerPreview.jpegCompressionQuality)
        #elseif canImport(AppKit)
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let fileType: NSBitmapImageRep.FileType = contentType.conforms(to: .png) ? .png : .jpeg
        let properties: [NSBitmapImageRep.PropertyKey: Any] = fileType == .jpeg
            ? [.compressionFactor: ComposerPreview.jpegCompressionQuality]
            : [:]
        return bitmap.representation(using: fileType, properties: properties)
        #else
        return nil
        #endif
    }
}
