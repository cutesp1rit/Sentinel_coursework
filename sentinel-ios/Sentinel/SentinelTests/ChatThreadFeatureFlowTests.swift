import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatThreadFeatureFlowTests {
    @Test
    func accessTokenAndActiveChatChangesResetThreadState() async {
        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.messages = [ChatThreadMessage(role: .assistant, text: "Body")]
        initialState.errorMessage = "error"
        initialState.hasMoreHistory = true
        initialState.isLoadingMessages = true

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        } withDependencies: {
            $0.chatClient.listMessages = { _, _, _, _ in ([], false) }
        }
        store.exhaustivity = .off

        await store.send(.activeChatChanged(Fixture.secondUserID))
        try? await Task.sleep(for: .milliseconds(20))
        #expect(store.state.activeChatID == Fixture.secondUserID)
        #expect(store.state.messages.isEmpty)
        #expect(store.state.errorMessage == nil)

        await store.send(.accessTokenChanged(nil)) {
            $0 = .init()
        }
    }

    @Test
    func attachmentsValidationHandlesTooLargeAndLimit() async {
        let store = TestStore(initialState: ChatThreadFeature.State()) {
            ChatThreadFeature()
        }

        await store.send(.attachmentsAdded([
            ChatComposerAttachment(
                data: Data(repeating: 0, count: ChatThreadFeature.Constants.maxAttachmentSize + 1),
                previewData: nil,
                filename: "big.png",
                mimeType: "image/png"
            )
        ])) {
            $0.errorMessage = L10n.ChatSheet.attachmentTooLarge
        }

        var crowded = ChatThreadFeature.State()
        crowded.composerAttachments = (0..<ChatThreadFeature.Constants.attachmentLimit).map { index in
            ChatComposerAttachment(
                data: Data([UInt8(index)]),
                previewData: nil,
                filename: "f\(index).png",
                mimeType: "image/png"
            )
        }
        let crowdedStore = TestStore(initialState: crowded) {
            ChatThreadFeature()
        }

        await crowdedStore.send(.attachmentsAdded([
            ChatComposerAttachment(data: Data([0x01]), previewData: nil, filename: "extra.png", mimeType: "image/png")
        ])) {
            $0.errorMessage = L10n.ChatSheet.attachmentLimitReached
        }
    }

    @Test
    func messagesLoadedAndFailuresUpdateHistoryState() async {
        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.activeChatID = Fixture.chatID
        initialState.messages = [ChatThreadMessage(role: .assistant, text: "Existing")]

        let loaded = [Fixture.chatMessage(role: .assistant, markdownText: "Loaded", actions: nil, images: [])]
        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }

        await store.send(.messagesLoaded(chatID: Fixture.chatID, messages: loaded, hasMore: true, reset: true, requestToken: "token")) {
            $0.messages = loaded.map(ChatThreadMessage.init)
            $0.hasMoreHistory = true
            $0.isLoadingMessages = false
            $0.isLoadingMoreHistory = false
            $0.shouldAutoScrollToBottom = true
        }

        await store.send(.messagesFailed("Boom", chatID: Fixture.chatID, requestToken: "token")) {
            $0.isLoadingMessages = false
            $0.isLoadingMoreHistory = false
            $0.errorMessage = "Boom"
        }
    }

    @Test
    func suggestionConflictAndToggleActionsMutatePayload() async {
        let message = ChatThreadMessage(
            chatMessage: Fixture.chatMessage(
                role: .assistant,
                markdownText: "Body",
                actions: [Fixture.eventAction(kind: .create, eventId: nil, title: "Plan")]
            )
        )
        let messageID = message.id
        let suggestionID = try! #require(message.suggestionsPayload?.suggestions.first?.id)

        var initialState = ChatThreadFeature.State()
        initialState.messages = [message]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }

        await store.send(.toggleSuggestionExpansion(messageID)) {
            $0.messages[0].suggestionsPayload?.isExpanded = false
        }

        await store.send(.toggleSuggestionSelection(messageID: messageID, suggestionID: suggestionID)) {
            $0.messages[0].suggestionsPayload?.selectedSuggestionIDs = [suggestionID]
        }

        await store.send(.suggestionConflictsLoaded(messageID: messageID, conflicts: [suggestionID: true])) {
            $0.messages[0].suggestionsPayload?.suggestions[0].hasConflict = true
        }
    }

    @Test
    func sendFlowFailedMarksPendingMessageAsFailed() async {
        let pendingID = Fixture.messageID
        var initialState = ChatThreadFeature.State()
        initialState.accessToken = "token"
        initialState.activeSendRequestID = Fixture.secondEventID
        initialState.pendingLocalMessageID = pendingID
        initialState.isSending = true
        initialState.sendStage = .delivering
        initialState.messages = [
            ChatThreadMessage(id: pendingID, role: .user, text: "Body", deliveryState: .sending)
        ]

        let store = TestStore(initialState: initialState) {
            ChatThreadFeature()
        }

        await store.send(.sendFlowFailed(
            requestID: Fixture.secondEventID,
            message: "Failed",
            restoreDraft: nil,
            restoreAttachments: [],
            activeChatID: Fixture.chatID,
            messages: nil,
            hasMore: false,
            messagePersisted: false,
            requestToken: "token"
        )) {
            $0.isSending = false
            $0.sendStage = nil
            $0.errorMessage = "Failed"
            $0.activeChatID = Fixture.chatID
            $0.messages[0].deliveryState = .failed
            $0.hasMoreHistory = false
            $0.activeSendRequestID = nil
            $0.pendingLocalMessageID = nil
        }
    }
}
