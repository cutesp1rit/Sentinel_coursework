import SentinelUI
import SentinelCore
import SentinelPlatformiOS
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension ChatThreadScreenView {
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
        return ChatComposerAttachmentFactory.makeAttachment(from: data, contentType: contentType, index: index)
    }

    func makeComposerAttachment(from image: UIImage, index: Int) -> ChatComposerAttachment? {
        guard let data = image.jpegData(compressionQuality: 0.92), !data.isEmpty else { return nil }
        return ChatComposerAttachmentFactory.makeAttachment(from: data, contentType: .jpeg, index: index)
    }

    func makeComposerAttachment(from fileURL: URL, index: Int) -> ChatComposerAttachment? {
        guard let contentType = UTType(filenameExtension: fileURL.pathExtension),
              contentType.conforms(to: .image),
              let data = try? Data(contentsOf: fileURL),
              !data.isEmpty else {
            return nil
        }
        return ChatComposerAttachmentFactory.makeAttachment(from: data, contentType: contentType, index: index)
    }
}
