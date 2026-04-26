import ComposableArchitecture
import Foundation

@Reducer
struct ChatThreadFeature {
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.chatClient) var chatClient
    @Dependency(\.eventsClient) var eventsClient
    @Dependency(\.localNotificationsClient) var localNotificationsClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .accessTokenChanged(token):
                state.accessToken = token
                guard token != nil else {
                    state = State()
                    return .none
                }
                return .none

            case let .activeChatChanged(chatID):
                guard chatID != state.activeChatID else { return .none }
                state.activeChatID = chatID
                state.messages = []
                state.errorMessage = nil
                state.hasMoreHistory = false
                state.isLoadingMessages = false
                state.isLoadingMoreHistory = false
                guard chatID != nil else { return .none }
                return .send(.loadMessagesRequested(reset: true))

            case let .attachmentsAdded(attachments):
                if attachments.contains(where: { $0.data.count > Constants.maxAttachmentSize }) {
                    state.errorMessage = L10n.ChatSheet.attachmentTooLarge
                    return .none
                }
                let availableSlots = max(Constants.attachmentLimit - state.composerAttachments.count, 0)
                if availableSlots == 0 {
                    state.errorMessage = L10n.ChatSheet.attachmentLimitReached
                    return .none
                }
                state.composerAttachments.append(contentsOf: attachments.prefix(availableSlots))
                state.errorMessage = attachments.count > availableSlots ? L10n.ChatSheet.attachmentLimitReached : nil
                return .none

            case let .attachmentRemoved(attachmentID):
                state.composerAttachments.removeAll { $0.id == attachmentID }
                return .none

            case let .addSelectedSuggestionsTapped(messageID):
                return applySuggestions(state: &state, messageID: messageID)

            case .autoScrollCompleted:
                state.shouldAutoScrollToBottom = false
                return .none

            case .composerFocusChanged:
                return .send(.delegate(.expandRequested))

            case let .draftChanged(draft):
                state.draft = draft
                return .none

            case let .loadMessagesRequested(reset):
                guard let accessToken = state.accessToken, let activeChatID = state.activeChatID else { return .none }
                if reset {
                    guard !state.isLoadingMessages else { return .none }
                    state.isLoadingMessages = true
                } else {
                    guard !state.isLoadingMoreHistory, state.messages.first != nil else { return .none }
                    state.isLoadingMoreHistory = true
                }
                state.errorMessage = nil
                let before = reset ? nil : state.messages.first?.id
                return .run { [chatClient] send in
                    do {
                        let (messages, hasMore) = try await chatClient.listMessages(activeChatID, before, Constants.pageSize, accessToken)
                        await send(.messagesLoaded(chatID: activeChatID, messages: messages, hasMore: hasMore, reset: reset, requestToken: accessToken))
                    } catch {
                        await send(.messagesFailed(Self.errorMessage(for: error), chatID: activeChatID, requestToken: accessToken))
                    }
                }

            case .loadMoreHistoryTapped:
                guard state.activeChatID != nil, state.hasMoreHistory else { return .none }
                return .send(.loadMessagesRequested(reset: false))

            case let .messagesFailed(message, chatID, requestToken):
                guard state.accessToken == requestToken, state.activeChatID == chatID else { return .none }
                state.isLoadingMessages = false
                state.isLoadingMoreHistory = false
                state.errorMessage = message
                return .none

            case let .messagesLoaded(chatID, messages, hasMore, reset, requestToken):
                guard state.accessToken == requestToken, state.activeChatID == chatID else { return .none }
                let mappedMessages = Self.mergingPreviewData(
                    loadedMessages: messages.map(ChatThreadMessage.init),
                    existingMessages: state.messages
                )
                state.messages = reset
                    ? mappedMessages
                    : Self.mergingOlderMessages(existing: state.messages, olderMessages: mappedMessages)
                state.hasMoreHistory = hasMore
                state.isLoadingMessages = false
                state.isLoadingMoreHistory = false
                state.shouldAutoScrollToBottom = reset
                return Self.refreshConflictEffects(for: state.messages)

            case .onAppear:
                guard state.activeChatID != nil, state.messages.isEmpty else { return .none }
                return .send(.loadMessagesRequested(reset: true))

            case let .refreshSuggestionConflictsRequested(messageID):
                guard let payload = state.messages.first(where: { $0.id == messageID })?.suggestionsPayload,
                      !payload.conflictDrafts.isEmpty else { return .none }
                return .run { [calendarSyncClient] send in
                    let conflicts = await calendarSyncClient.detectConflicts(payload.conflictDrafts)
                    await send(.suggestionConflictsLoaded(messageID: messageID, conflicts: conflicts))
                }

            case .retryTapped:
                guard state.activeChatID != nil else { return .none }
                return .send(.loadMessagesRequested(reset: true))

            case .sendButtonTapped:
                return sendMessage(state: &state)

            case let .sendFlowCompleted(requestID, _, activeChatID, messages, assistantMessage, hasMore, requestToken):
                guard state.accessToken == requestToken, state.activeSendRequestID == requestID else { return .none }
                state.activeChatID = activeChatID
                state.messages = Self.mergingPreviewData(
                    loadedMessages: messages.map(ChatThreadMessage.init),
                    existingMessages: state.messages
                )
                state.hasMoreHistory = hasMore
                state.pendingLocalMessageID = nil
                state.activeSendRequestID = nil
                state.shouldAutoScrollToBottom = true
                let refreshSuggestions = assistantMessage.content.eventActions != nil
                    ? Effect<Action>.send(.refreshSuggestionConflictsRequested(assistantMessage.id))
                    : .none
                return .merge(
                    .send(.delegate(.chatActivated(activeChatID))),
                    .send(.delegate(.chatListShouldReload(activeChatID))),
                    refreshSuggestions
                )

            case let .sendFlowFailed(requestID, message, restoreDraft, restoreAttachments, activeChatID, messages, hasMore, messagePersisted, requestToken):
                guard state.accessToken == requestToken, state.activeSendRequestID == requestID else { return .none }
                state.isSending = false
                state.sendStage = nil
                state.activeSendRequestID = nil
                state.pendingLocalMessageID = nil
                state.errorMessage = message
                if let restoreDraft { state.draft = restoreDraft }
                if !restoreAttachments.isEmpty { state.composerAttachments = restoreAttachments }
                if let activeChatID { state.activeChatID = activeChatID }
                if let messages {
                    state.messages = messagePersisted ? messages.map(ChatThreadMessage.init) : state.messages.dropLast().map { $0 }
                } else if !messagePersisted, !state.messages.isEmpty {
                    state.messages.removeLast()
                }
                if let hasMore { state.hasMoreHistory = hasMore }
                return .none

            case let .sendResponseReceived(requestID, activeChatID, assistantMessage, requestToken):
                guard state.accessToken == requestToken, state.activeSendRequestID == requestID else { return .none }
                state.activeChatID = activeChatID
                state.isSending = false
                state.sendStage = nil
                if let pendingLocalMessageID = state.pendingLocalMessageID,
                   let index = state.messages.firstIndex(where: { $0.id == pendingLocalMessageID }) {
                    state.messages[index].deliveryState = .delivered
                }
                if !state.messages.contains(where: { $0.id == assistantMessage.id }) {
                    state.messages.append(.init(chatMessage: assistantMessage))
                }
                state.shouldAutoScrollToBottom = true
                return assistantMessage.content.eventActions != nil
                    ? .send(.refreshSuggestionConflictsRequested(assistantMessage.id))
                    : .none

            case let .sendStageChanged(stage, requestID):
                guard state.activeSendRequestID == requestID else { return .none }
                state.sendStage = stage
                return .none

            case let .suggestionApplyCompleted(messageID, updatedMessage, requestToken):
                guard state.accessToken == requestToken,
                      let index = state.messages.firstIndex(where: { $0.id == messageID }) else { return .none }
                state.messages[index] = Self.mergingUpdatedMessage(updatedMessage: updatedMessage, existingMessage: state.messages[index])
                state.errorMessage = nil
                return .merge(
                    .send(.delegate(.suggestionsApplied)),
                    .send(.refreshSuggestionConflictsRequested(messageID))
                )

            case let .suggestionApplyFailed(messageID, message, requestToken):
                guard state.accessToken == requestToken,
                      let index = state.messages.firstIndex(where: { $0.id == messageID }) else { return .none }
                if var payload = state.messages[index].suggestionsPayload {
                    payload.isApplying = false
                    state.messages[index].suggestionsPayload = payload
                }
                state.errorMessage = message
                return .none

            case let .suggestionConflictsLoaded(messageID, conflicts):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }),
                      let payload = state.messages[index].suggestionsPayload else { return .none }
                state.messages[index].suggestionsPayload = payload.updatingConflicts(conflicts)
                return .none

            case let .toggleSuggestionExpansion(messageID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }),
                      var payload = state.messages[index].suggestionsPayload else { return .none }
                payload.isExpanded.toggle()
                state.messages[index].suggestionsPayload = payload
                return .none

            case let .toggleSuggestionSelection(messageID, suggestionID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }),
                      var payload = state.messages[index].suggestionsPayload else { return .none }
                if payload.selectedSuggestionIDs.contains(suggestionID) {
                    payload.selectedSuggestionIDs.remove(suggestionID)
                } else {
                    payload.selectedSuggestionIDs.insert(suggestionID)
                }
                state.messages[index].suggestionsPayload = payload
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
