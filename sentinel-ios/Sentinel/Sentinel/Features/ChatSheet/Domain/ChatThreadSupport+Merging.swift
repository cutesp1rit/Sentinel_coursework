import ComposableArchitecture
import Foundation

extension ChatThreadFeature {
    static func mergingOlderMessages(existing: [ChatThreadMessage], olderMessages: [ChatThreadMessage]) -> [ChatThreadMessage] {
        var merged = olderMessages
        for message in existing where !merged.contains(where: { $0.id == message.id }) {
            merged.append(message)
        }
        return mergingPreviewData(loadedMessages: merged, existingMessages: existing)
    }

    static func mergingUpdatedMessage(updatedMessage: ChatMessage, existingMessage: ChatThreadMessage) -> ChatThreadMessage {
        var mergedMessage = ChatThreadMessage(chatMessage: updatedMessage)
        if let existingPayload = existingMessage.suggestionsPayload,
           let updatedPayload = mergedMessage.suggestionsPayload {
            mergedMessage.suggestionsPayload = .init(
                isApplying: false,
                suggestions: updatedPayload.suggestions,
                isExpanded: existingPayload.isExpanded,
                selectedSuggestionIDs: existingPayload.selectedSuggestionIDs
            )
        }
        return mergedMessage
    }

    static func mergingPreviewData(
        loadedMessages: [ChatThreadMessage],
        existingMessages: [ChatThreadMessage]
    ) -> [ChatThreadMessage] {
        var unmatchedExistingMessages = existingMessages.filter { !$0.images.isEmpty }

        return loadedMessages.map { loadedMessage in
            guard let candidateIndex = unmatchedExistingMessages.lastIndex(where: {
                messageMatchesForPreview(loadedMessage, existingMessage: $0)
            }) else {
                return loadedMessage
            }

            let existingMessage = unmatchedExistingMessages.remove(at: candidateIndex)
            return applyingPreviewData(from: existingMessage, to: loadedMessage)
        }
    }

    static func refreshConflictEffects(for messages: [ChatThreadMessage]) -> Effect<Action> {
        .merge(
            messages.compactMap { message in
                guard let payload = message.suggestionsPayload, !payload.conflictDrafts.isEmpty else { return nil }
                return .send(.refreshSuggestionConflictsRequested(message.id))
            }
        )
    }

    private static func messageMatchesForPreview(
        _ loadedMessage: ChatThreadMessage,
        existingMessage: ChatThreadMessage
    ) -> Bool {
        loadedMessage.role == existingMessage.role
            && loadedMessage.markdownText == existingMessage.markdownText
            && loadedMessage.images.map(\.filename) == existingMessage.images.map(\.filename)
    }

    private static func applyingPreviewData(
        from existingMessage: ChatThreadMessage,
        to loadedMessage: ChatThreadMessage
    ) -> ChatThreadMessage {
        var mergedMessage = loadedMessage
        let previewDataByFilename = Dictionary(
            uniqueKeysWithValues: existingMessage.images.map { ($0.filename, $0.previewData) }
        )

        mergedMessage.images = loadedMessage.images.map { image in
            ChatImageAttachment(
                url: image.url,
                filename: image.filename,
                localData: nil,
                mimeType: image.mimeType,
                previewData: image.previewData ?? previewDataByFilename[image.filename] ?? nil
            )
        }
        return mergedMessage
    }
}
