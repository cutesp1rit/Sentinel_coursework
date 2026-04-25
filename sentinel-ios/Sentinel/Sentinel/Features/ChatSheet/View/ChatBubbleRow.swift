import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ChatBubbleRow: View {
    let message: ChatThreadMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            if message.isUser {
                Spacer(minLength: AppSizing.minimumHitTarget)

                bubbleBody(foregroundStyle: .white)
                    .background(
                        Color.blue,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
            } else {
                bubbleBody(foregroundStyle: .primary)
                    .background(
                        AppPlatformColor.tertiaryGroupedBackground,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )

                Spacer(minLength: AppSizing.minimumHitTarget)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bubbleBody(foregroundStyle: some ShapeStyle) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !message.images.isEmpty {
                imageGrid
            }

            if let attributedText = message.attributedText {
                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(foregroundStyle)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium)
        .frame(maxWidth: AppGrid.value(68), alignment: .leading)
    }

    private var imageGrid: some View {
        VStack(spacing: AppSpacing.small) {
            ForEach(message.images) { attachment in
                attachmentView(attachment)
                    .frame(maxWidth: AppGrid.value(68) - (AppSpacing.large * 2))
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func attachmentView(_ attachment: ChatImageAttachment) -> some View {
        if let data = attachment.previewData,
           let image = PlatformImage(data: data) {
            platformImageView(image)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: attachment.url) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackImage
                case .empty:
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.08))
                        ProgressView()
                    }
                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Rectangle()
            .fill(AppPlatformColor.tertiaryGroupedBackground)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}

private extension ChatThreadMessage {
    var attributedText: AttributedString? {
        guard let markdownText, !markdownText.isEmpty else {
            return nil
        }
        return (try? AttributedString(markdown: markdownText)) ?? AttributedString(markdownText)
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage

private func platformImageView(_ image: UIImage) -> Image {
    Image(uiImage: image)
}
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage

private func platformImageView(_ image: NSImage) -> Image {
    Image(nsImage: image)
}
#endif
