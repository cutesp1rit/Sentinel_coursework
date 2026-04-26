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

                userMessageBody
            } else {
                assistantMessageBody

                Spacer(minLength: AppSizing.minimumHitTarget)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var userMessageBody: some View {
        VStack(alignment: .trailing, spacing: AppSpacing.small) {
            if !message.images.isEmpty {
                imageGrid
                    .frame(width: maxBubbleImageGridWidth, alignment: .trailing)
            }

            if let attributedText = message.attributedText {
                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.medium)
                    .frame(maxWidth: AppGrid.value(68), alignment: .leading)
                    .background(
                        Color.blue,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
            }
        }
    }

    private var assistantMessageBody: some View {
        bubbleBody(foregroundStyle: .primary)
            .background(
                AppPlatformColor.tertiaryGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            )
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
        LazyVGrid(columns: imageGridColumns, alignment: .leading, spacing: AppSpacing.small) {
            ForEach(message.images) { attachment in
                attachmentView(attachment)
                    .frame(width: imageGridItemSide, height: imageGridItemSide)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            }
        }
        .frame(width: maxBubbleImageGridWidth, alignment: .leading)
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

    private var imageGridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: AppSpacing.small),
            count: min(max(message.images.count, 1), 3)
        )
    }

    private var imageGridItemSide: CGFloat {
        let columnCount = CGFloat(min(max(message.images.count, 1), 3))
        let totalSpacing = AppSpacing.small * (columnCount - 1)
        return floor((maxBubbleImageGridWidth - totalSpacing) / columnCount)
    }

    private var maxBubbleImageGridWidth: CGFloat {
        AppGrid.value(68) - (AppSpacing.large * 2)
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
