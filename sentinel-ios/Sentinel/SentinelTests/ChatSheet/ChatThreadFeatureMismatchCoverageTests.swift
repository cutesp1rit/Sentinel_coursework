import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct ChatThreadFeatureMismatchCoverageTests {
    @Test
    func messagesAndSuggestionMismatchBranchesIgnoreUnexpectedInputs() async {
        var state = ChatThreadFeature.State()
        state.accessToken = "token"
        state.activeChatID = Fixture.chatID
        state.messages = [ChatThreadMessage(chatMessage: Fixture.chatMessage())]
        state.activeSendRequestID = Fixture.messageID

        let store = TestStore(initialState: state) {
            ChatThreadFeature()
        }

        await store.send(.messagesFailed("ignored", chatID: Fixture.secondUserID, requestToken: "token"))
        await store.send(.messagesFailed("ignored", chatID: Fixture.chatID, requestToken: "other"))
        await store.send(.messagesLoaded(chatID: Fixture.secondUserID, messages: [], hasMore: false, reset: true, requestToken: "token"))
        await store.send(.messagesLoaded(chatID: Fixture.chatID, messages: [], hasMore: false, reset: true, requestToken: "other"))

        await store.send(.suggestionApplyCompleted(
            messageID: UUID(),
            updatedMessage: Fixture.chatMessage(role: .assistant, markdownText: "Updated", actions: nil, images: []),
            requestToken: "token"
        ))
        await store.send(.suggestionApplyCompleted(
            messageID: store.state.messages[0].id,
            updatedMessage: Fixture.chatMessage(role: .assistant, markdownText: "Updated", actions: nil, images: []),
            requestToken: "other"
        ))

        await store.send(.suggestionConflictsLoaded(messageID: UUID(), conflicts: [:]))
        await store.send(.toggleSuggestionExpansion(UUID()))
        await store.send(.toggleSuggestionSelection(messageID: UUID(), suggestionID: "missing"))
    }

    @Test
    func sendCompletionAndResponseBranchesHandleNilActionsAndMismatchedTokens() async {
        let assistant = Fixture.chatMessage(role: .assistant, markdownText: "Reply", actions: nil, images: [])
        var state = ChatThreadFeature.State()
        state.accessToken = "token"
        state.activeSendRequestID = Fixture.messageID
        state.pendingLocalMessageID = Fixture.chatID
        state.messages = [ChatThreadMessage(id: Fixture.chatID, role: .user, text: "Pending", deliveryState: .sending)]

        let store = TestStore(initialState: state) {
            ChatThreadFeature()
        }
        store.exhaustivity = .off

        await store.send(.sendResponseReceived(
            requestID: Fixture.messageID,
            activeChatID: Fixture.chatID,
            assistantMessage: assistant,
            requestToken: "token"
        ))
        #expect(store.state.activeChatID == Fixture.chatID)
        #expect(store.state.messages[0].deliveryState == .delivered)
        #expect(store.state.messages.contains(where: { $0.id == assistant.id }))
        #expect(store.state.shouldAutoScrollToBottom)

        await store.send(.sendFlowCompleted(
            requestID: UUID(),
            chats: [],
            activeChatID: Fixture.chatID,
            messages: [],
            assistantMessage: assistant,
            hasMore: false,
            requestToken: "token"
        ))
        await store.send(.sendFlowCompleted(
            requestID: Fixture.messageID,
            chats: [],
            activeChatID: Fixture.chatID,
            messages: [],
            assistantMessage: assistant,
            hasMore: false,
            requestToken: "other"
        ))
    }
}
