import Foundation
import SwiftUI

struct ChatBubbleRow: View {
    let message: ChatSheetState.Message

    private var attributedText: AttributedString {
        guard let markdownText = message.markdownText else { return AttributedString("") }
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

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            if message.isUser {
                Spacer(minLength: AppSizing.minimumHitTarget)

                bubbleText(foregroundStyle: .white)
                    .background(
                        Color.blue,
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
            } else {
                bubbleText(foregroundStyle: .primary)
                    .background(
                        Color(uiColor: .secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )

                Spacer(minLength: AppSizing.minimumHitTarget)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func bubbleText(foregroundStyle: some ShapeStyle) -> some View {
        Text(attributedText)
            .font(.body)
            .foregroundStyle(foregroundStyle)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .frame(width: estimatedBubbleWidth, alignment: .leading)
    }
}
