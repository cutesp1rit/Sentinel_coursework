import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ChatBubbleRow: View {
    let message: ChatSheetState.Message

    private var attributedText: AttributedString {
        guard let markdownText = message.markdownText, !markdownText.isEmpty else {
            return AttributedString("")
        }
        return (try? AttributedString(markdown: markdownText)) ?? AttributedString(markdownText)
    }

    private var bubbleMaxWidth: CGFloat {
        AppGrid.value(68)
    }

    private var estimatedBubbleWidth: CGFloat {
        guard let text = message.markdownText, !text.isEmpty else {
            return AppGrid.value(18)
        }

        let compactText = text.replacingOccurrences(of: "\n", with: " ")
        let estimated = CGFloat(compactText.count) * 11 + (AppSpacing.large * 2)
        return min(max(estimated, AppGrid.value(18)), bubbleMaxWidth)
    }

    private var hasText: Bool {
        !(message.markdownText?.isEmpty ?? true)
    }

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

            if hasText {
                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(foregroundStyle)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium)
        .frame(
            width: message.images.isEmpty ? estimatedBubbleWidth : nil,
            alignment: .leading
        )
        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
    }

    private var imageGrid: some View {
        VStack(spacing: AppSpacing.small) {
            ForEach(message.images) { attachment in
                attachmentView(attachment)
                    .frame(maxWidth: bubbleMaxWidth - (AppSpacing.large * 2))
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
