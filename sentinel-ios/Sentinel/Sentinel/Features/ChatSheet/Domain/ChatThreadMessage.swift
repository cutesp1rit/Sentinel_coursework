import SentinelUI
import SentinelCore
import Foundation
import SwiftUI

struct ChatThreadMessage: Equatable, Identifiable {
    enum Role: Equatable {
        case user
        case assistant
    }

    enum DeliveryState: Equatable {
        case delivered
        case failed
        case sending
    }

    struct SuggestionsPayload: Equatable {
        var isApplying = false
        var suggestions: [ChatSuggestion]
        var isExpanded = true
        var selectedSuggestionIDs: Set<ChatSuggestion.ID> = []
    }

    let id: UUID
    let role: Role
    var deliveryState: DeliveryState
    var images: [ChatImageAttachment]
    var markdownText: String?
    var suggestionsPayload: SuggestionsPayload?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        images: [ChatImageAttachment] = [],
        deliveryState: DeliveryState = .delivered
    ) {
        self.id = id
        self.role = role
        self.deliveryState = deliveryState
        self.images = images
        markdownText = text
        suggestionsPayload = nil
    }

    init(chatMessage: ChatMessage) {
        id = chatMessage.id
        role = chatMessage.role == .user ? .user : .assistant
        deliveryState = .delivered
        images = chatMessage.content.images
        markdownText = chatMessage.content.markdownText
        suggestionsPayload = chatMessage.content.eventActions.map { eventActions in
            .init(
                suggestions: eventActions.actions.enumerated().map { index, action in
                    ChatSuggestion(actionIndex: index, action: action)
                }
            )
        }
    }

    var isUser: Bool {
        role == .user
    }

    var failedComposerAttachments: [ChatComposerAttachment] {
        images.compactMap { image in
            guard let data = image.localData ?? image.previewData else { return nil }
            return ChatComposerAttachment(
                data: data,
                previewData: image.previewData ?? data,
                filename: image.filename,
                mimeType: image.mimeType
            )
        }
    }

    var hasBubbleContent: Bool {
        markdownText != nil || !images.isEmpty
    }

    var isFailedToSend: Bool {
        deliveryState == .failed
    }
}

enum ChatSendStage: Equatable {
    case delivering
    case syncing
}

extension ChatThreadMessage.SuggestionsPayload {
    func isSelected(_ suggestionID: ChatSuggestion.ID) -> Bool {
        selectedSuggestionIDs.contains(suggestionID)
    }

    var selectedPendingCount: Int {
        suggestions.filter {
            selectedSuggestionIDs.contains($0.id) && $0.status == .pending
        }.count
    }

    var isSingleSuggestion: Bool {
        suggestions.count == 1
    }

    var addToCalendarTitle: String {
        if isApplying {
            return L10n.ChatSheet.syncingToCalendar
        }
        if !hasPendingSuggestions {
            return L10n.ChatSheet.applied
        }
        if suggestions.count == 1 || selectedPendingCount == 0 {
            return L10n.ChatSheet.addToCalendar
        }
        return L10n.ChatSheet.addCountToCalendar(selectedPendingCount)
    }

    var canAddToCalendar: Bool {
        guard !isApplying, hasPendingSuggestions else {
            return false
        }
        let pendingSuggestions = suggestions.filter { $0.status == .pending }
        return pendingSuggestions.count == 1 || selectedPendingCount > 0
    }
}

extension Array where Element == ChatThreadMessage {
    func spacing(after index: Int) -> CGFloat {
        guard indices.contains(index + 1) else { return 0 }
        return self[index].role == self[index + 1].role ? AppSpacing.small : AppSpacing.medium
    }
}
