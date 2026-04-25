import SwiftUI

struct ChatSheetTranscriptView: View {
    let detent: ChatSheetState.Detent
    let messages: [ChatSheetState.Message]
    let onToggleSuggestionExpansion: (ChatSheetState.Message.ID) -> Void
    let onToggleSuggestionSelection: (ChatSheetState.Message.ID, ChatSheetState.Suggestion.ID) -> Void
    let onAddSelectedSuggestions: (ChatSheetState.Message.ID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                messageRow(for: message)
                    .padding(.bottom, messageSpacing(after: index))
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
    private func messageRow(for message: ChatSheetState.Message) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if message.markdownText != nil || !message.images.isEmpty {
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

    private func messageSpacing(after index: Int) -> CGFloat {
        guard messages.indices.contains(index + 1) else { return 0 }
        return messages[index].role == messages[index + 1].role ? AppSpacing.small : AppSpacing.medium
    }
}

private struct SuggestionsMessageRowView: View {
    let messageID: ChatSheetState.Message.ID
    let payload: ChatSheetState.Message.SuggestionsPayload
    let onToggleExpansion: (ChatSheetState.Message.ID) -> Void
    let onToggleSuggestionSelection: (ChatSheetState.Message.ID, ChatSheetState.Suggestion.ID) -> Void
    let onAddSelectedSuggestions: (ChatSheetState.Message.ID) -> Void

    private var addToCalendarTitle: String {
        if payload.isApplying {
            return L10n.ChatSheet.syncingToCalendar
        }

        if !payload.hasPendingSuggestions {
            return L10n.ChatSheet.applied
        }

        if payload.suggestions.count == 1 || selectedPendingCount == 0 {
            return L10n.ChatSheet.addToCalendar
        }
        return L10n.ChatSheet.addCountToCalendar(selectedPendingCount)
    }

    private var isSingleSuggestion: Bool {
        payload.suggestions.count == 1
    }

    private var selectedPendingCount: Int {
        payload.suggestions.filter {
            payload.selectedSuggestionIDs.contains($0.id) && $0.status == .pending
        }.count
    }

    private var canAddToCalendar: Bool {
        guard !payload.isApplying, payload.hasPendingSuggestions else {
            return false
        }

        let pendingSuggestions = payload.suggestions.filter { $0.status == .pending }
        return pendingSuggestions.count == 1 || selectedPendingCount > 0
    }

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

                        if selectedPendingCount > 0 {
                            Text(L10n.ChatSheet.selectedCount(selectedPendingCount))
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
                                isSelected: payload.selectedSuggestionIDs.contains(suggestion.id),
                                showsSelectionControl: !isSingleSuggestion && suggestion.status == .pending,
                                isInteractive: !isSingleSuggestion && suggestion.status == .pending && !payload.isApplying
                            ) {
                                onToggleSuggestionSelection(messageID, suggestion.id)
                            }
                        }

                        Button {
                            onAddSelectedSuggestions(messageID)
                        } label: {
                            Text(addToCalendarTitle)
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
                                .opacity(canAddToCalendar ? 1 : AppOpacity.disabled)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAddToCalendar)
                    }
                }
            }
            .padding(AppSpacing.large)
            .background(
                Color(uiColor: .secondarySystemFill),
                in: RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
            )

            Spacer(minLength: AppSizing.minimumHitTarget)
        }
    }
}
