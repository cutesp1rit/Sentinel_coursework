import Foundation

struct ChatComposerAttachment: Equatable, Identifiable {
    let id: UUID
    let data: Data
    let previewData: Data?
    let filename: String
    let mimeType: String

    init(
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

    var imageAttachment: ChatImageAttachment {
        ChatImageAttachment(
            url: "",
            filename: filename,
            localData: data,
            mimeType: mimeType,
            previewData: previewData ?? data
        )
    }
}
