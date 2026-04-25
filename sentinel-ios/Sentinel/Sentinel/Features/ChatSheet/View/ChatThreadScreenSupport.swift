import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension ChatThreadScreenView {
    func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        }
    }

    func makeComposerAttachments(from items: [PhotosPickerItem]) async -> [ChatComposerAttachment] {
        var attachments: [ChatComposerAttachment] = []
        for (index, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else { continue }
            let contentType = item.supportedContentTypes.first ?? .png
            let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
            let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
            let filename = "photo-\(UUID().uuidString.prefix(8))-\(index + 1).\(fileExtension)"
            attachments.append(.init(data: data, filename: filename, mimeType: mimeType))
        }
        return attachments
    }
}
