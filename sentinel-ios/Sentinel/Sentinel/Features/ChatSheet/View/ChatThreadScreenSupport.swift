import PhotosUI
import Photos
import SwiftUI
import UniformTypeIdentifiers
import ImageIO

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
struct RecentLibraryPhoto: Identifiable {
    let assetIdentifier: String
    let thumbnail: UIImage

    var id: String { assetIdentifier }
}
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
        return makeComposerAttachment(from: data, contentType: contentType, index: index)
    }

    func makeComposerAttachment(from image: UIImage, index: Int) -> ChatComposerAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.92), !data.isEmpty else { return nil }
        return makeComposerAttachment(from: data, contentType: .jpeg, index: index)
    }

    func makeComposerAttachment(from fileURL: URL, index: Int) -> ChatComposerAttachment? {
        guard let contentType = UTType(filenameExtension: fileURL.pathExtension),
              contentType.conforms(to: .image),
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty else {
            return nil
        }
        return makeComposerAttachment(from: data, contentType: contentType, index: index)
    }

    func makeComposerAttachment(from recentPhoto: RecentLibraryPhoto, index: Int) async -> ChatComposerAttachment? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [recentPhoto.assetIdentifier], options: nil).firstObject,
              let payload = await loadImageData(for: asset) else {
            return nil
        }

        return makeComposerAttachment(from: payload.data, contentType: payload.contentType, index: index)
    }

    func loadRecentLibraryPhotos(limit: Int) async -> [RecentLibraryPhoto] {
        let authorizationStatus = await requestPhotoLibraryAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            return []
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = limit
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var recentPhotos: [RecentLibraryPhoto] = []
        assets.enumerateObjects { asset, _, stop in
            guard let thumbnail = thumbnailImage(for: asset) else { return }
            recentPhotos.append(.init(assetIdentifier: asset.localIdentifier, thumbnail: thumbnail))
            if recentPhotos.count >= limit {
                stop.pointee = true
            }
        }
        return recentPhotos
    }

    private func makeComposerAttachment(from data: Data, contentType: UTType, index: Int) -> ChatComposerAttachment? {
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

    private func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return status
    }

    private func thumbnailImage(for asset: PHAsset) -> UIImage? {
        let manager = PHCachingImageManager()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        options.resizeMode = .exact

        let targetSize = CGSize(width: 180, height: 180)
        var thumbnail: UIImage?
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            thumbnail = image
        }
        return thumbnail
    }

    private func loadImageData(for asset: PHAsset) async -> (data: Data, contentType: UTType)? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.version = .current

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
                guard let data, !data.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let contentType = dataUTI.flatMap(UTType.init) ?? .jpeg
                continuation.resume(returning: (data, contentType))
            }
        }
    }
}
