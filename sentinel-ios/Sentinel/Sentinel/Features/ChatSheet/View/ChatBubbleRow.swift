import Foundation
import SwiftUI

struct ChatBubbleRow: View {
    let message: ChatSheetState.Message

    private var attributedText: AttributedString {
        guard let markdownText = message.markdownText else { return AttributedString("") }
        return (try? AttributedString(markdown: markdownText)) ?? AttributedString(markdownText)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            if message.isUser {
                Spacer(minLength: AppSizing.minimumHitTarget)

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
                    .padding(.trailing, AppSpacing.medium)
            } else {
                AssistantAvatarView()

                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.medium)
                    .background(
                        Color(uiColor: .secondarySystemFill),
                        in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    )
                    .frame(maxWidth: AppGrid.value(72), alignment: .leading)

                Spacer(minLength: AppSizing.minimumHitTarget)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
