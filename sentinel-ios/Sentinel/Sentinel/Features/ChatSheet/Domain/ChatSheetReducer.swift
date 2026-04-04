import ComposableArchitecture
import Foundation

@Reducer
struct ChatSheetReducer {
    @Dependency(\.chatClient) var chatClient

    private enum Constants {
        static let pageSize = 100
    }

    var body: some Reducer<ChatSheetState, ChatSheetAction> {
        Reduce { state, action in
            switch action {
            case let .accessTokenChanged(token):
                let didChange = state.accessToken != token
                state.accessToken = token

                guard didChange else { return .none }

                guard token != nil else {
                    state.activeChatID = nil
                    state.chatSummaries = []
                    state.draft = ""
                    state.messages = []
                    state.pendingLocalMessageID = nil
                    state.sendStage = nil
                    state.hasLoadedChats = false
                    state.hasMoreHistory = false
                    state.isChatListPresented = false
                    state.isLoadingChats = false
                    state.isLoadingMessages = false
                    state.isLoadingMoreHistory = false
                    state.isSending = false
                    state.errorMessage = nil
                    state.shouldAutoScrollToBottom = false
                    return .none
                }

                state.errorMessage = nil
                state.hasLoadedChats = false
                return .send(.loadChatsRequested(preferredActiveChatID: state.activeChatID))

            case .addAttachmentTapped:
                if state.detent == .collapsed {
                    state.detent = .medium
                }
                return .none

            case .addSelectedSuggestionsTapped:
                return .none

            case .autoScrollCompleted:
                state.shouldAutoScrollToBottom = false
                return .none

            case .chatListButtonTapped:
                guard state.isSignedIn else { return .none }
                state.isChatListPresented = true
                return .none

            case let .chatListPresentationChanged(isPresented):
                state.isChatListPresented = isPresented
                return .none

            case let .chatSelected(chatID):
                state.isChatListPresented = false
                state.errorMessage = nil

                guard chatID != state.activeChatID else { return .none }

                state.activeChatID = chatID
                state.messages = []
                state.hasMoreHistory = false

                guard let chatID else { return .none }
                return .send(.loadMessagesRequested(chatID: chatID, reset: true))

            case let .chatsFailed(message, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.isLoadingChats = false
                state.errorMessage = message
                return .none

            case let .chatsLoaded(chats, preferredActiveChatID, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.chatSummaries = chats.map(ChatSheetState.ChatSummary.init)
                state.hasLoadedChats = true
                state.isLoadingChats = false

                let nextActiveChatID = preferredActiveChatID
                    ?? state.activeChatID.flatMap { activeChatID in
                        state.chatSummaries.contains(where: { $0.id == activeChatID }) ? activeChatID : nil
                    }
                    ?? state.chatSummaries.first?.id

                guard let nextActiveChatID else {
                    state.activeChatID = nil
                    state.messages = []
                    state.hasMoreHistory = false
                    return .none
                }

                let shouldReloadMessages = state.activeChatID != nextActiveChatID || state.messages.isEmpty
                state.activeChatID = nextActiveChatID

                guard shouldReloadMessages else { return .none }
                return .send(.loadMessagesRequested(chatID: nextActiveChatID, reset: true))

            case let .composerFocusChanged(isFocused):
                if isFocused {
                    state.detent = .large
                }
                return .none

            case let .detentChanged(detent):
                state.detent = detent
                return .none

            case let .draftChanged(draft):
                state.draft = draft
                return .none

            case let .loadChatsRequested(preferredActiveChatID):
                guard let accessToken = state.accessToken, !state.isLoadingChats else {
                    return .none
                }

                state.isLoadingChats = true
                state.errorMessage = nil
                return .run { [chatClient] send in
                    do {
                        let chats = try await chatClient.listChats(accessToken)
                        await send(.chatsLoaded(
                            chats,
                            preferredActiveChatID: preferredActiveChatID,
                            requestToken: accessToken
                        ))
                    } catch {
                        await send(.chatsFailed(Self.errorMessage(for: error), requestToken: accessToken))
                    }
                }

            case let .loadMessagesRequested(chatID, reset):
                guard let accessToken = state.accessToken else {
                    return .none
                }

                if reset {
                    guard !state.isLoadingMessages else { return .none }
                    state.isLoadingMessages = true
                } else {
                    guard !state.isLoadingMoreHistory, let before = state.messages.first?.id else {
                        return .none
                    }
                    state.isLoadingMoreHistory = true
                    _ = before
                }

                let before = reset ? nil : state.messages.first?.id
                state.errorMessage = nil

                return .run { [chatClient] send in
                    do {
                        let (messages, hasMore) = try await chatClient.listMessages(
                            chatID,
                            before,
                            Constants.pageSize,
                            accessToken
                        )
                        await send(.messagesLoaded(
                            chatID: chatID,
                            messages: messages,
                            hasMore: hasMore,
                            reset: reset,
                            requestToken: accessToken
                        ))
                    } catch {
                        await send(.messagesFailed(Self.errorMessage(for: error), requestToken: accessToken))
                    }
                }

            case .loadMoreHistoryTapped:
                guard let activeChatID = state.activeChatID, state.hasMoreHistory else {
                    return .none
                }
                return .send(.loadMessagesRequested(chatID: activeChatID, reset: false))

            case let .messagesFailed(message, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.isLoadingMessages = false
                state.isLoadingMoreHistory = false
                state.errorMessage = message
                return .none

            case let .messagesLoaded(chatID, messages, hasMore, reset, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard state.activeChatID == chatID else { return .none }

                let mappedMessages = messages.map(ChatSheetState.Message.init)
                if reset {
                    state.messages = mappedMessages
                    state.shouldAutoScrollToBottom = true
                } else {
                    state.messages = Self.mergingOlderMessages(
                        existing: state.messages,
                        olderMessages: mappedMessages
                    )
                    state.shouldAutoScrollToBottom = false
                }
                state.hasMoreHistory = hasMore
                state.isLoadingMessages = false
                state.isLoadingMoreHistory = false
                return .none

            case .onAppear:
                guard state.isSignedIn, !state.hasLoadedChats else { return .none }
                return .send(.loadChatsRequested(preferredActiveChatID: state.activeChatID))

            case .retryTapped:
                if let activeChatID = state.activeChatID, state.isSignedIn {
                    return .send(.loadMessagesRequested(chatID: activeChatID, reset: true))
                }
                if state.isSignedIn {
                    return .send(.loadChatsRequested(preferredActiveChatID: state.activeChatID))
                }
                return .none

            case let .sendStageChanged(stage):
                state.sendStage = stage
                return .none

            case .sendButtonTapped:
                if state.detent == .collapsed {
                    state.detent = .medium
                    return .none
                }

                guard let accessToken = state.accessToken else {
                    state.errorMessage = L10n.ChatSheet.authRequiredBody
                    return .none
                }

                guard !state.isSending else { return .none }

                let trimmedDraft = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedDraft.isEmpty else { return .none }

                let pendingLocalMessageID = UUID()
                let existingActiveChatID = state.activeChatID
                state.isSending = true
                state.errorMessage = nil
                state.pendingLocalMessageID = pendingLocalMessageID
                state.sendStage = .delivering
                state.messages.append(
                    .init(
                        id: pendingLocalMessageID,
                        role: .user,
                        text: trimmedDraft,
                        deliveryState: .sending
                    )
                )
                state.shouldAutoScrollToBottom = true
                state.draft = ""
                return .run { [chatClient] send in
                    var activeChatID: UUID?
                    do {
                        if let existingActiveChatID {
                            activeChatID = existingActiveChatID
                        } else {
                            let createdChat = try await chatClient.createChat(
                                Self.chatTitle(from: trimmedDraft),
                                accessToken
                            )
                            activeChatID = createdChat.id
                        }

                        _ = try await chatClient.sendMessage(
                            activeChatID!,
                            "user",
                            trimmedDraft,
                            accessToken
                        )
                        await send(.sendStageChanged(.syncing))
                        let chats = try await chatClient.listChats(accessToken)
                        let (messages, hasMore) = try await chatClient.listMessages(
                            activeChatID!,
                            nil,
                            Constants.pageSize,
                            accessToken
                        )

                        await send(.sendFlowCompleted(
                            chats: chats,
                            activeChatID: activeChatID!,
                            messages: messages,
                            hasMore: hasMore,
                            requestToken: accessToken
                        ))
                    } catch {
                        let chats = try? await chatClient.listChats(accessToken)
                        let transcript: ([ChatMessage], Bool)?
                        let messagePersisted: Bool
                        if let activeChatID {
                            transcript = try? await chatClient.listMessages(
                                activeChatID,
                                nil,
                                Constants.pageSize,
                                accessToken
                            )
                            messagePersisted = await MainActor.run {
                                transcript?.0.contains(where: { message in
                                    switch message.role {
                                    case .user:
                                        return message.content.markdownText == trimmedDraft
                                    case .assistant, .system, .tool:
                                        return false
                                    }
                                }) ?? false
                            }
                        } else {
                            transcript = nil
                            messagePersisted = false
                        }
                        await send(.sendFlowFailed(
                            message: Self.errorMessage(for: error),
                            restoreDraft: messagePersisted ? nil : trimmedDraft,
                            chats: chats,
                            activeChatID: activeChatID,
                            messages: transcript?.0,
                            hasMore: transcript?.1,
                            messagePersisted: messagePersisted,
                            requestToken: accessToken
                        ))
                    }
                }

            case let .sendFlowCompleted(chats, activeChatID, messages, hasMore, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.isSending = false
                state.chatSummaries = chats.map(ChatSheetState.ChatSummary.init)
                state.hasLoadedChats = true
                state.activeChatID = activeChatID
                state.messages = messages.map(ChatSheetState.Message.init)
                state.hasMoreHistory = hasMore
                state.pendingLocalMessageID = nil
                state.sendStage = nil
                state.shouldAutoScrollToBottom = true
                return .none

            case let .sendFlowFailed(message, restoreDraft, chats, activeChatID, messages, hasMore, messagePersisted, requestToken):
                guard state.accessToken == requestToken else { return .none }
                state.isSending = false
                state.errorMessage = message
                state.sendStage = nil
                if let restoreDraft {
                    state.draft = restoreDraft
                }
                if let chats {
                    state.chatSummaries = chats.map(ChatSheetState.ChatSummary.init)
                    state.hasLoadedChats = true
                }
                if let activeChatID {
                    state.activeChatID = activeChatID
                }
                if let messages {
                    state.messages = messages.map(ChatSheetState.Message.init)
                }
                if !messagePersisted, let pendingLocalMessageID = state.pendingLocalMessageID {
                    state.messages.removeAll(where: { $0.id == pendingLocalMessageID })
                }
                state.pendingLocalMessageID = nil
                if let hasMore {
                    state.hasMoreHistory = hasMore
                }
                return .none

            case let .toggleSuggestionExpansion(messageID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }) else {
                    return .none
                }
                guard var payload = state.messages[index].suggestionsPayload else {
                    return .none
                }

                payload.isExpanded.toggle()
                state.messages[index].suggestionsPayload = payload
                return .none

            case let .toggleSuggestionSelection(messageID, suggestionID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }) else {
                    return .none
                }
                guard var payload = state.messages[index].suggestionsPayload else {
                    return .none
                }

                if payload.selectedSuggestionIDs.contains(suggestionID) {
                    payload.selectedSuggestionIDs.remove(suggestionID)
                } else {
                    payload.selectedSuggestionIDs.insert(suggestionID)
                }

                state.messages[index].suggestionsPayload = payload
                return .none
            }
        }
    }
}

private extension ChatSheetReducer {
    static func chatTitle(from draft: String) -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return L10n.ChatSheet.newChat
        }

        return String(trimmed.prefix(40))
    }

    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }

        return error.localizedDescription
    }

    static func mergingOlderMessages(
        existing: [ChatSheetState.Message],
        olderMessages: [ChatSheetState.Message]
    ) -> [ChatSheetState.Message] {
        var seen = Set(existing.map(\.id))
        let uniqueOlder = olderMessages.filter { seen.insert($0.id).inserted }
        return uniqueOlder + existing
    }
}
