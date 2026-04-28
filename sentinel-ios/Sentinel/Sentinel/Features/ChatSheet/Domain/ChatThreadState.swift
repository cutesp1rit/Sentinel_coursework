import ComposableArchitecture
import Foundation

extension ChatThreadFeature {
    @ObservableState
    struct State: Equatable {
        var accessToken: String?
        var activeChatID: UUID?
        var composerAttachments: [ChatComposerAttachment] = []
        var draft = ""
        var errorMessage: String?
        var hasMoreHistory = false
        var isLoadingMessages = false
        var isLoadingMoreHistory = false
        var isSending = false
        var messages: [ChatThreadMessage] = []
        var activeSendRequestID: UUID?
        var pendingLocalMessageID: ChatThreadMessage.ID?
        var sendStage: ChatSendStage?
        var shouldAutoScrollToBottom = false

        var hasComposerContent: Bool {
            !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !composerAttachments.isEmpty
        }

        var isSignedIn: Bool {
            accessToken != nil
        }
    }

    enum Action: Equatable {
        case accessTokenChanged(String?)
        case activeChatChanged(UUID?)
        case attachmentsAdded([ChatComposerAttachment])
        case attachmentRemoved(ChatComposerAttachment.ID)
        case addSelectedSuggestionsTapped(ChatThreadMessage.ID)
        case autoScrollCompleted
        case composerFocusChanged
        case draftChanged(String)
        case failedMessageRemoveTapped(ChatThreadMessage.ID)
        case failedMessageRetryTapped(ChatThreadMessage.ID)
        case loadMessagesRequested(reset: Bool)
        case loadMoreHistoryTapped
        case messagesFailed(String, chatID: UUID, requestToken: String)
        case messagesLoaded(chatID: UUID, messages: [ChatMessage], hasMore: Bool, reset: Bool, requestToken: String)
        case onAppear
        case refreshSuggestionConflictsRequested(ChatThreadMessage.ID)
        case retryTapped
        case sendButtonTapped
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
            restoreAttachments: [ChatComposerAttachment],
            activeChatID: UUID?,
            messages: [ChatMessage]?,
            hasMore: Bool?,
            messagePersisted: Bool,
            requestToken: String
        )
        case sendResponseReceived(
            requestID: UUID,
            activeChatID: UUID,
            assistantMessage: ChatMessage,
            requestToken: String
        )
        case sendStageChanged(ChatSendStage?, requestID: UUID)
        case suggestionApplyCompleted(
            messageID: ChatThreadMessage.ID,
            updatedMessage: ChatMessage,
            requestToken: String
        )
        case suggestionApplyFailed(
            messageID: ChatThreadMessage.ID,
            message: String,
            requestToken: String
        )
        case suggestionConflictsLoaded(
            messageID: ChatThreadMessage.ID,
            conflicts: [ChatSuggestion.ID: Bool]
        )
        case toggleSuggestionExpansion(ChatThreadMessage.ID)
        case toggleSuggestionSelection(messageID: ChatThreadMessage.ID, suggestionID: ChatSuggestion.ID)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case chatActivated(UUID?)
        case chatListShouldReload(UUID?)
        case expandRequested
        case suggestionsApplied
    }

    enum Constants {
        static let attachmentLimit = 5
        static let maxAttachmentSize = 10 * 1024 * 1024
        static let pageSize = 100
    }
}
