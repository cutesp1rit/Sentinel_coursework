import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatThreadFeatureReducerExtraCoverageTests {
    @Test
    func suggestionMutationBranchesToggleAndResetPayloadState() async {
        let suggestion = ChatSuggestion(actionIndex: 0, action: Fixture.eventAction(kind: .create, eventId: nil, title: "Plan"))
        var message = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                markdownText: "Assistant",
                actions: [Fixture.eventAction(kind: .create, eventId: nil, title: "Plan")]
            )
        )
        message.suggestionsPayload?.isApplying = true

        var state = ChatThreadFeature.State()
        state.accessToken = "token"
        state.messages = [message]

        let store = TestStore(initialState: state) {
            ChatThreadFeature()
        }
        store.exhaustivity = .off

        await store.send(.toggleSuggestionExpansion(message.id)) {
            $0.messages[0].suggestionsPayload?.isExpanded = false
        }

        await store.send(.toggleSuggestionSelection(messageID: message.id, suggestionID: suggestion.id)) {
            $0.messages[0].suggestionsPayload?.selectedSuggestionIDs = [suggestion.id]
        }

        await store.send(.toggleSuggestionSelection(messageID: message.id, suggestionID: suggestion.id)) {
            $0.messages[0].suggestionsPayload?.selectedSuggestionIDs = []
        }

        await store.send(.suggestionApplyFailed(messageID: message.id, message: "Apply failed", requestToken: "token")) {
            $0.messages[0].suggestionsPayload?.isApplying = false
            $0.errorMessage = "Apply failed"
        }

        await store.send(.suggestionConflictsLoaded(messageID: message.id, conflicts: [suggestion.id: true])) {
            $0.messages[0].suggestionsPayload?.suggestions[0].hasConflict = true
        }

        await store.send(.suggestionApplyFailed(messageID: UUID(), message: "ignored", requestToken: "token"))
    }

    @Test
    func sendStageAndSendResultMismatchBranchesIgnoreUnexpectedEvents() async {
        var state = ChatThreadFeature.State()
        state.accessToken = "token"
        state.activeSendRequestID = Fixture.messageID
        state.pendingLocalMessageID = Fixture.chatID
        state.messages = [ChatThreadMessage(id: Fixture.chatID, role: .user, text: "Pending", deliveryState: .sending)]

        let store = TestStore(initialState: state) {
            ChatThreadFeature()
        }
        store.exhaustivity = .off

        await store.send(.sendStageChanged(.syncing, requestID: UUID()))
        #expect(store.state.sendStage == nil)

        await store.send(.sendStageChanged(.syncing, requestID: Fixture.messageID)) {
            $0.sendStage = .syncing
        }

        await store.send(.sendResponseReceived(
            requestID: UUID(),
            activeChatID: Fixture.chatID,
            assistantMessage: Fixture.chatMessage(role: .assistant, markdownText: "Reply", actions: nil, images: []),
            requestToken: "token"
        ))
        #expect(store.state.messages.count == 1)

        await store.send(.sendFlowFailed(
            requestID: UUID(),
            message: "ignored",
            restoreDraft: nil,
            restoreAttachments: [],
            activeChatID: nil,
            messages: nil,
            hasMore: nil,
            messagePersisted: false,
            requestToken: "token"
        ))
        #expect(store.state.errorMessage == nil)
    }

    @Test
    func recentPhotoSelectionDelegateLoadsAttachmentUsingCurrentComposerIndex() async {
        let attachment = ChatComposerAttachment(
            data: Data([0x01]),
            previewData: nil,
            filename: "recent.jpg",
            mimeType: "image/jpeg"
        )

        var state = ChatThreadFeature.State()
        state.composerAttachments = [
            ChatComposerAttachment(data: Data([0x02]), previewData: nil, filename: "first.jpg", mimeType: "image/jpeg")
        ]

        let store = TestStore(initialState: state) {
            ChatThreadFeature()
        } withDependencies: {
            $0.chatAttachmentLibraryClient.makeAttachmentFromRecentPhoto = { photoID, index in
                #expect(photoID == "asset-9")
                #expect(index == 1)
                return attachment
            }
        }
        store.exhaustivity = .off

        await store.send(.attachmentPicker(.delegate(.recentPhotoSelected("asset-9"))))
        await store.receive(.recentPhotoAttachmentLoaded("asset-9", attachment)) {
            $0.recentPhotoAttachmentIDs["asset-9"] = attachment.id
        }
        await store.receive(.attachmentsAdded([attachment]))
        #expect(store.state.composerAttachments.count == 2)

        await store.send(.attachmentPicker(.delegate(.recentPhotoDeselected("missing"))))
        #expect(store.state.composerAttachments.count == 2)
    }
}
