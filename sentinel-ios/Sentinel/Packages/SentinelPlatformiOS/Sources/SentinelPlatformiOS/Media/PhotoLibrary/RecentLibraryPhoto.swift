import Foundation

public struct RecentLibraryPhoto: Equatable, Identifiable, Sendable {
    public let assetIdentifier: String
    public let thumbnailData: Data

    public var id: String { assetIdentifier }

    public init(assetIdentifier: String, thumbnailData: Data) {
        self.assetIdentifier = assetIdentifier
        self.thumbnailData = thumbnailData
    }
}
