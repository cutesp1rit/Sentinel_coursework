import ComposableArchitecture
import SentinelCore
import Photos
import UIKit
import UniformTypeIdentifiers

public struct ChatAttachmentLibraryClient: Sendable {
    public var loadRecentPhotos: @Sendable (_ limit: Int) async -> [RecentLibraryPhoto]
    public var makeAttachmentFromRecentPhoto: @Sendable (_ assetIdentifier: String, _ index: Int) async -> ChatComposerAttachment?

    public init(
        loadRecentPhotos: @escaping @Sendable (_ limit: Int) async -> [RecentLibraryPhoto],
        makeAttachmentFromRecentPhoto: @escaping @Sendable (_ assetIdentifier: String, _ index: Int) async -> ChatComposerAttachment?
    ) {
        self.loadRecentPhotos = loadRecentPhotos
        self.makeAttachmentFromRecentPhoto = makeAttachmentFromRecentPhoto
    }
}

extension ChatAttachmentLibraryClient: DependencyKey {
    public static let liveValue = Self(
        loadRecentPhotos: { limit in
            let authorizationStatus = await Self.requestPhotoLibraryAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return []
            }

            let identifiers = await MainActor.run {
                let fetchOptions = PHFetchOptions()
                fetchOptions.fetchLimit = limit
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

                let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                var identifiers: [String] = []

                assets.enumerateObjects { asset, _, stop in
                    identifiers.append(asset.localIdentifier)
                    if identifiers.count >= limit {
                        stop.pointee = true
                    }
                }

                return identifiers
            }

            var recentPhotos: [RecentLibraryPhoto] = []
            recentPhotos.reserveCapacity(identifiers.count)

            for identifier in identifiers {
                guard let thumbnailData = await Self.thumbnailData(for: identifier) else { continue }
                recentPhotos.append(
                    .init(
                        assetIdentifier: identifier,
                        thumbnailData: thumbnailData
                    )
                )
            }

            return recentPhotos
        },
        makeAttachmentFromRecentPhoto: { assetIdentifier, index in
            let authorizationStatus = await Self.requestPhotoLibraryAuthorization()
            guard authorizationStatus == .authorized || authorizationStatus == .limited else {
                return nil
            }
            let asset = await MainActor.run {
                PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
            }
            guard let asset,
                  let payload = await Self.loadImageData(for: asset) else {
                return nil
            }

            return await MainActor.run {
                ChatComposerAttachmentFactory.makeAttachment(
                    from: payload.data,
                    contentType: payload.contentType,
                    index: index
                )
            }
        }
    )

    private static func requestPhotoLibraryAuthorization() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return status
    }

    private static func thumbnailData(for assetIdentifier: String) async -> Data? {
        let asset = await MainActor.run {
            PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
        }
        guard let asset,
              let payload = await loadImageData(for: asset) else {
            return nil
        }

        return ChatComposerAttachmentFactory.makePreviewData(
            from: payload.data,
            contentType: payload.contentType,
            maxPixelSize: 180
        )
    }

    private static func loadImageData(for asset: PHAsset) async -> (data: Data, contentType: UTType)? {
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

public extension DependencyValues {
    nonisolated var chatAttachmentLibraryClient: ChatAttachmentLibraryClient {
        get { self[ChatAttachmentLibraryClient.self] }
        set { self[ChatAttachmentLibraryClient.self] = newValue }
    }
}
