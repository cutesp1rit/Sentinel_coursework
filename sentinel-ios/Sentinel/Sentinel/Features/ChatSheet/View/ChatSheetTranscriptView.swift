import SwiftUI

struct ChatSheetTranscriptView: View {
    let detent: ChatSheetState.Detent
    let messages: [ChatThreadMessage]
    let onToggleSuggestionExpansion: (ChatThreadMessage.ID) -> Void
    let onToggleSuggestionSelection: (ChatThreadMessage.ID, ChatSuggestion.ID) -> Void
    let onAddSelectedSuggestions: (ChatThreadMessage.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                messageRow(for: message)
                    .padding(.bottom, messages.spacing(after: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(
            .horizontal,
            detent == .large
                ? 12
                : 16
        )
        .padding(.top, 10)
    }

    @ViewBuilder
    private func messageRow(for message: ChatThreadMessage) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if message.hasBubbleContent {
                ChatBubbleRow(message: message)
            }

            if let payload = message.suggestionsPayload {
                SuggestionsMessageRowView(
                    messageID: message.id,
                    payload: payload,
                    onToggleExpansion: onToggleSuggestionExpansion,
                    onToggleSuggestionSelection: onToggleSuggestionSelection,
                    onAddSelectedSuggestions: onAddSelectedSuggestions
                )
            }
        }
    }

}

private struct SuggestionsMessageRowView: View {
    let messageID: ChatThreadMessage.ID
    let payload: ChatThreadMessage.SuggestionsPayload
    let onToggleExpansion: (ChatThreadMessage.ID) -> Void
    let onToggleSuggestionSelection: (ChatThreadMessage.ID, ChatSuggestion.ID) -> Void
    let onAddSelectedSuggestions: (ChatThreadMessage.ID) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Button {
                    onToggleExpansion(messageID)
                } label: {
                    HStack(spacing: AppSpacing.medium) {
                        Text(L10n.ChatSheet.suggestedEvents)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        if payload.selectedPendingCount > 0 {
                            Text(L10n.ChatSheet.selectedCount(payload.selectedPendingCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: payload.isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if payload.isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        ForEach(payload.suggestions) { suggestion in
                            SuggestionCardView(
                                suggestion: suggestion,
                                isSelected: payload.isSelected(suggestion.id),
                                showsSelectionControl: !payload.isSingleSuggestion && suggestion.status == .pending,
                                isInteractive: !payload.isSingleSuggestion && suggestion.status == .pending && !payload.isApplying
                            ) {
                                onToggleSuggestionSelection(messageID, suggestion.id)
                            }
                        }

                        Button {
                            onAddSelectedSuggestions(messageID)
                        } label: {
                            Text(payload.addToCalendarTitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.large)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color.blue,
                                            Color.blue.opacity(0.88)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                        .stroke(
                                            Color.white.opacity(AppOpacity.secondaryBorder),
                                            lineWidth: AppStrokeWidth.standard
                                        )
                                }
                                .shadow(color: Color.blue.opacity(0.18), radius: 10, y: 4)
                                .opacity(payload.canAddToCalendar ? 1 : AppOpacity.disabled)
                        }
                        .buttonStyle(.plain)
                        .disabled(!payload.canAddToCalendar)
                    }
                }
            }
            .padding(AppSpacing.large)
            .background(
                AppPlatformColor.tertiaryGroupedBackground,
                in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            )

            Spacer(minLength: AppSizing.minimumHitTarget)
        }
    }
}
