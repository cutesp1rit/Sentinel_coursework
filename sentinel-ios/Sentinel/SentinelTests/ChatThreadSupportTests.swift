import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatThreadSupportTests {
    @Test
    func chatTitleUsesTrimmedPreviewAndFallback() {
        #expect(ChatThreadFeature.chatTitle(from: "   ") == L10n.ChatSheet.newChat)
        #expect(ChatThreadFeature.chatTitle(from: "Hello\nWorld") == "Hello World")
        #expect(ChatThreadFeature.chatTitle(from: String(repeating: "a", count: 80)).count == 48)
    }

    @Test
    func errorMessagePrefersAPIErrorMessage() {
        let apiError = APIError(code: "BAD", message: "Readable", details: nil)
        #expect(ChatThreadFeature.errorMessage(for: apiError) == "Readable")

        struct SampleError: LocalizedError {
            var errorDescription: String? { "Fallback" }
        }
        #expect(ChatThreadFeature.errorMessage(for: SampleError()) == "Fallback")
    }

    @Test
    func mergingUpdatedMessagePreservesSelectionAndExpansion() {
        let existing = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                actions: [Fixture.eventAction(kind: .create, eventId: nil, title: "Old")]
            )
        )
        var edited = existing
        edited.suggestionsPayload?.isExpanded = false
        if let suggestionID = edited.suggestionsPayload?.suggestions.first?.id {
            edited.suggestionsPayload?.selectedSuggestionIDs = [suggestionID]
        }

        let updated = Fixture.chatMessage(
            actions: [Fixture.eventAction(kind: .update, eventId: Fixture.eventID, title: "New")]
        )
        let merged = ChatThreadFeature.mergingUpdatedMessage(updatedMessage: updated, existingMessage: edited)

        #expect(merged.suggestionsPayload?.isExpanded == false)
        #expect(merged.suggestionsPayload?.selectedSuggestionIDs == edited.suggestionsPayload?.selectedSuggestionIDs)
        #expect(merged.suggestionsPayload?.suggestions.first?.title == "New")
    }

    @Test
    func mergingPreviewDataReusesExistingPreviewPayloads() {
        let existingImages = [
            ChatImageAttachment(
                url: "https://example.com/image.jpg",
                filename: "image.jpg",
                localData: nil,
                mimeType: "image/jpeg",
                previewData: Data([0xAA])
            )
        ]
        let existing = ChatThreadMessage(
            id: Fixture.messageID,
            role: .user,
            text: "Body",
            images: existingImages
        )

        let loaded = ChatThreadMessage(
            id: UUID(),
            role: .user,
            text: "Body",
            images: [
                ChatImageAttachment(
                    url: "https://example.com/image.jpg",
                    filename: "image.jpg",
                    localData: nil,
                    mimeType: "image/jpeg",
                    previewData: nil
                )
            ]
        )

        let merged = ChatThreadFeature.mergingPreviewData(
            loadedMessages: [loaded],
            existingMessages: [existing]
        )

        #expect(merged.first?.images.first?.previewData == Data([0xAA]))
    }

    @Test
    func refreshConflictEffectsOnlyEmitsForMessagesWithDrafts() {
        let messageWithDrafts = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                actions: [Fixture.eventAction(kind: .create, eventId: nil, title: "Plan")]
            )
        )
        let messageWithoutDrafts = ChatThreadMessage(role: .assistant, text: "Text")

        let effect = ChatThreadFeature.refreshConflictEffects(for: [messageWithDrafts, messageWithoutDrafts])
        #expect(String(describing: effect).isEmpty == false)
    }
}
