import Foundation

enum ChatSheetAction: Equatable {
    case accessTokenChanged(String?)
    case addAttachmentTapped
    case addSelectedSuggestionsTapped(ChatSheetState.Message.ID)
    case autoScrollCompleted
    case chatListButtonTapped
    case chatListPresentationChanged(Bool)
    case chatSelected(UUID?)
    case chatsFailed(String, requestToken: String)
    case chatsLoaded([Chat], preferredActiveChatID: UUID?, requestToken: String)
    case composerFocusChanged(Bool)
    case detentChanged(ChatSheetState.Detent)
    case draftChanged(String)
    case loadChatsRequested(preferredActiveChatID: UUID?)
    case loadMessagesRequested(chatID: UUID, reset: Bool)
    case loadMoreHistoryTapped
    case messagesFailed(String, requestToken: String)
    case messagesLoaded(chatID: UUID, messages: [ChatMessage], hasMore: Bool, reset: Bool, requestToken: String)
    case onAppear
    case retryTapped
    case sendButtonTapped
    case sendResponseReceived(
        requestID: UUID,
        activeChatID: UUID,
        assistantMessage: ChatMessage,
        requestToken: String
    )
    case sendStageChanged(ChatSheetState.SendStage?, requestID: UUID)
    case sendFlowCompleted(
        requestID: UUID,
        chats: [Chat],
        activeChatID: UUID,
        messages: [ChatMessage],
        assistantMessage: ChatMessage,
        hasMore: Bool,
        requestToken: String
    )
    case sendFlowFailed(
        requestID: UUID,
        message: String,
        restoreDraft: String?,
        chats: [Chat]?,
        activeChatID: UUID?,
        messages: [ChatMessage]?,
        hasMore: Bool?,
        messagePersisted: Bool,
        requestToken: String
    )
    case toggleSuggestionExpansion(ChatSheetState.Message.ID)
    case toggleSuggestionSelection(
        messageID: ChatSheetState.Message.ID,
        suggestionID: ChatSheetState.Suggestion.ID
    )
}
