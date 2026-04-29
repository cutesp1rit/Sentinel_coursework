import Foundation

public struct ChatComposerAttachment: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let data: Data
    public let previewData: Data?
    public let filename: String
    public let mimeType: String

    public init(
        id: UUID = UUID(),
        data: Data,
        previewData: Data? = nil,
        filename: String,
        mimeType: String
    ) {
        self.id = id
        self.data = data
        self.previewData = previewData
        self.filename = filename
        self.mimeType = mimeType
    }

    public var imageAttachment: ChatImageAttachment {
        ChatImageAttachment(
            url: "",
            filename: filename,
            localData: data,
            mimeType: mimeType,
            previewData: previewData ?? data
        )
    }
}
