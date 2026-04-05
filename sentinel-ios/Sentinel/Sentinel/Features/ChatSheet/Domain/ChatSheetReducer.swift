import ComposableArchitecture
import Foundation

@Reducer
struct ChatSheetReducer {
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.chatClient) var chatClient
    @Dependency(\.eventsClient) var eventsClient

    private enum Constants {
        static let pageSize = 100
        static let recoveryPollAttempts = 6
        static let recoveryPollDelayNanoseconds: UInt64 = 5_000_000_000
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
                    state.activeSendRequestID = nil
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

            case let .addSelectedSuggestionsTapped(messageID):
                guard let accessToken = state.accessToken,
                      let activeChatID = state.activeChatID,
                      let messageIndex = state.messages.firstIndex(where: { $0.id == messageID }),
                      var payload = state.messages[messageIndex].suggestionsPayload,
                      let applyPlan = payload.applyingSelectionPlan() else {
                    return .none
                }

                payload.isApplying = true
                state.messages[messageIndex].suggestionsPayload = payload
                state.errorMessage = nil
                return .run { [calendarSyncClient, chatClient, eventsClient] send in
                    do {
                        let updatedMessage: ChatMessage
                        do {
                            updatedMessage = try await chatClient.applyActions(
                                activeChatID,
                                messageID,
                                applyPlan.acceptedIndices,
                                accessToken
                            )
                        } catch {
                            throw NSError(
                                domain: "ChatProposalApply",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Apply failed: \(Self.errorMessage(for: error))"]
                            )
                        }

                        var canonicalEventsByID: [UUID: Event] = [:]

                        if let syncRange = applyPlan.syncRange {
                            let rangedEvents: [Event]
                            do {
                                rangedEvents = try await eventsClient.listEvents(
                                    syncRange.lowerBound,
                                    syncRange.upperBound,
                                    accessToken
                                )
                            } catch {
                                throw NSError(
                                    domain: "ChatProposalApply",
                                    code: 2,
                                    userInfo: [NSLocalizedDescriptionKey: "Events refresh failed: \(Self.errorMessage(for: error))"]
                                )
                            }
                            canonicalEventsByID = Dictionary(
                                uniqueKeysWithValues: rangedEvents.map { ($0.id, $0) }
                            )
                        }

                        for eventID in applyPlan.upsertEventIDs
                        where !canonicalEventsByID.keys.contains(eventID) {
                            let event: Event
                            do {
                                event = try await eventsClient.getEvent(eventID, accessToken)
                            } catch {
                                throw NSError(
                                    domain: "ChatProposalApply",
                                    code: 3,
                                    userInfo: [NSLocalizedDescriptionKey: "Event fetch failed: \(Self.errorMessage(for: error))"]
                                )
                            }
                            canonicalEventsByID[eventID] = event
                        }

                        if !canonicalEventsByID.isEmpty || !applyPlan.deletedEventIDs.isEmpty {
                            do {
                                _ = try await calendarSyncClient.sync(
                                    .init(
                                        deletedEventIDs: applyPlan.deletedEventIDs,
                                        events: Array(canonicalEventsByID.values)
                                    )
                                )
                            } catch {
                                throw NSError(
                                    domain: "ChatProposalApply",
                                    code: 4,
                                    userInfo: [NSLocalizedDescriptionKey: "Calendar sync failed: \(Self.errorMessage(for: error))"]
                                )
                            }
                        }

                        await send(.suggestionApplyCompleted(
                            messageID: messageID,
                            updatedMessage: updatedMessage,
                            requestToken: accessToken
                        ))
                    } catch {
                        await send(.suggestionApplyFailed(
                            messageID: messageID,
                            message: Self.errorMessage(for: error),
                            requestToken: accessToken
                        ))
                    }
                }

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
                return Self.refreshConflictEffects(for: state.messages)

            case .onAppear:
                guard state.isSignedIn, !state.hasLoadedChats else { return .none }
                return .send(.loadChatsRequested(preferredActiveChatID: state.activeChatID))

            case let .refreshSuggestionConflictsRequested(messageID):
                guard let message = state.messages.first(where: { $0.id == messageID }),
                      let payload = message.suggestionsPayload,
                      !payload.conflictDrafts.isEmpty else {
                    return .none
                }

                return .run { [calendarSyncClient] send in
                    let conflicts = await calendarSyncClient.detectConflicts(payload.conflictDrafts)
                    await send(.suggestionConflictsLoaded(messageID: messageID, conflicts: conflicts))
                }

            case .retryTapped:
                if let activeChatID = state.activeChatID, state.isSignedIn {
                    return .send(.loadMessagesRequested(chatID: activeChatID, reset: true))
                }
                if state.isSignedIn {
                    return .send(.loadChatsRequested(preferredActiveChatID: state.activeChatID))
                }
                return .none

            case let .sendResponseReceived(requestID, activeChatID, assistantMessage, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard state.activeSendRequestID == requestID else {
                    return .none
                }

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
                if assistantMessage.content.eventActions != nil {
                    return .send(.refreshSuggestionConflictsRequested(assistantMessage.id))
                }
                return .none

            case let .sendStageChanged(stage, requestID):
                guard state.activeSendRequestID == requestID else { return .none }
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
                let requestID = UUID()
                let existingActiveChatID = state.activeChatID
                let existingServerMessageCount = state.messages.count
                state.isSending = true
                state.errorMessage = nil
                state.activeSendRequestID = requestID
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

                        let assistantMessage = try await chatClient.sendMessage(
                            activeChatID!,
                            "user",
                            trimmedDraft,
                            accessToken
                        )
                        await send(.sendResponseReceived(
                            requestID: requestID,
                            activeChatID: activeChatID!,
                            assistantMessage: assistantMessage,
                            requestToken: accessToken
                        ))
                        await send(.sendStageChanged(.syncing, requestID: requestID))
                        let chats = try await chatClient.listChats(accessToken)
                        let (messages, hasMore) = try await chatClient.listMessages(
                            activeChatID!,
                            nil,
                            Constants.pageSize,
                            accessToken
                        )

                        await send(.sendFlowCompleted(
                            requestID: requestID,
                            chats: chats,
                            activeChatID: activeChatID!,
                            messages: messages,
                            assistantMessage: assistantMessage,
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

                        if let activeChatID,
                           Self.shouldAttemptRecoveryPolling(for: error) {
                            let recoveryPollAttempts = 6
                            let recoveryPollDelayNanoseconds: UInt64 = 5_000_000_000
                            for _ in 1...recoveryPollAttempts {
                                try? await Task.sleep(nanoseconds: recoveryPollDelayNanoseconds)
                                guard let recoveredTranscript = try? await chatClient.listMessages(
                                    activeChatID,
                                    nil,
                                    Constants.pageSize,
                                    accessToken
                                ) else {
                                    continue
                                }

                                let recoveredCount = recoveredTranscript.0.count
                                let latestMessageIsAssistant: Bool
                                if let lastMessage = recoveredTranscript.0.last {
                                    switch lastMessage.role {
                                    case .assistant:
                                        latestMessageIsAssistant = true
                                    case .user, .system, .tool:
                                        latestMessageIsAssistant = false
                                    }
                                } else {
                                    latestMessageIsAssistant = false
                                }

                                if recoveredCount > existingServerMessageCount,
                                   latestMessageIsAssistant {
                                    let recoveredChats = (try? await chatClient.listChats(accessToken)) ?? chats ?? []
                                    await send(.sendFlowCompleted(
                                        requestID: requestID,
                                        chats: recoveredChats,
                                        activeChatID: activeChatID,
                                        messages: recoveredTranscript.0,
                                        assistantMessage: recoveredTranscript.0.last!,
                                        hasMore: recoveredTranscript.1,
                                        requestToken: accessToken
                                    ))
                                    return
                                }

                                let transcriptDidNotAdvance = recoveredCount <= existingServerMessageCount
                                if transcriptDidNotAdvance && !latestMessageIsAssistant {
                                    break
                                }
                            }
                        }

                        await send(.sendFlowFailed(
                            requestID: requestID,
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

            case let .sendFlowCompleted(requestID, chats, activeChatID, messages, assistantMessage, hasMore, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard state.activeSendRequestID == requestID else {
                    return .none
                }
                state.chatSummaries = chats.map(ChatSheetState.ChatSummary.init)
                state.hasLoadedChats = true
                state.activeChatID = activeChatID
                let mergedMessages = Self.mergingLatestMessages(
                    fetchedMessages: messages,
                    assistantMessage: assistantMessage
                )
                state.messages = mergedMessages.map(ChatSheetState.Message.init)
                state.hasMoreHistory = hasMore
                state.activeSendRequestID = nil
                state.sendStage = nil
                state.shouldAutoScrollToBottom = true
                return Self.refreshConflictEffects(for: state.messages)

            case let .sendFlowFailed(requestID, message, restoreDraft, chats, activeChatID, messages, hasMore, messagePersisted, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard state.activeSendRequestID == requestID else {
                    return .none
                }
                state.isSending = false
                state.errorMessage = message
                state.activeSendRequestID = nil
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
                return Self.refreshConflictEffects(for: state.messages)

            case let .suggestionApplyCompleted(messageID, updatedMessage, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard let messageIndex = state.messages.firstIndex(where: { $0.id == messageID }) else {
                    return .none
                }

                let existingMessage = state.messages[messageIndex]
                state.messages[messageIndex] = Self.mergingSuggestionPresentation(
                    updatedMessage: updatedMessage,
                    existingMessage: existingMessage
                )
                state.errorMessage = nil
                return .none

            case let .suggestionApplyFailed(messageID, message, requestToken):
                guard state.accessToken == requestToken else { return .none }
                guard let messageIndex = state.messages.firstIndex(where: { $0.id == messageID }),
                      var payload = state.messages[messageIndex].suggestionsPayload else {
                    return .none
                }

                payload.isApplying = false
                state.messages[messageIndex].suggestionsPayload = payload
                state.errorMessage = message
                return .none

            case let .suggestionConflictsLoaded(messageID, conflicts):
                guard let messageIndex = state.messages.firstIndex(where: { $0.id == messageID }),
                      var payload = state.messages[messageIndex].suggestionsPayload else {
                    return .none
                }

                payload = payload.updatingConflicts(conflicts)
                state.messages[messageIndex].suggestionsPayload = payload
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
                guard !payload.isApplying else { return .none }
                guard let suggestion = payload.suggestions.first(where: { $0.id == suggestionID }),
                      suggestion.status == .pending else {
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

    nonisolated static func errorMessage(for error: Error) -> String {
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

    static func mergingLatestMessages(
        fetchedMessages: [ChatMessage],
        assistantMessage: ChatMessage
    ) -> [ChatMessage] {
        if fetchedMessages.contains(where: { $0.id == assistantMessage.id }) {
            return fetchedMessages
        }

        return fetchedMessages + [assistantMessage]
    }

    static func mergingSuggestionPresentation(
        updatedMessage: ChatMessage,
        existingMessage: ChatSheetState.Message
    ) -> ChatSheetState.Message {
        var mergedMessage = ChatSheetState.Message(chatMessage: updatedMessage)
        guard var mergedPayload = mergedMessage.suggestionsPayload,
              let existingPayload = existingMessage.suggestionsPayload else {
            return mergedMessage
        }

        let conflictsByActionIndex = Dictionary(
            uniqueKeysWithValues: existingPayload.suggestions.map { ($0.actionIndex, $0.hasConflict) }
        )
        mergedPayload.isApplying = false
        mergedPayload.suggestions = mergedPayload.suggestions.map { suggestion in
            var updatedSuggestion = suggestion
            updatedSuggestion.hasConflict = conflictsByActionIndex[suggestion.actionIndex] ?? suggestion.hasConflict
            return updatedSuggestion
        }
        mergedMessage.suggestionsPayload = mergedPayload
        return mergedMessage
    }

    static func refreshConflictEffects(
        for messages: [ChatSheetState.Message]
    ) -> Effect<ChatSheetAction> {
        .merge(
            messages.compactMap { message in
                guard let payload = message.suggestionsPayload,
                      !payload.conflictDrafts.isEmpty else {
                    return nil
                }

                return .send(.refreshSuggestionConflictsRequested(message.id))
            }
        )
    }

    nonisolated static func shouldAttemptRecoveryPolling(for error: Error) -> Bool {
        let message = errorMessage(for: error).lowercased()
        return message.contains("timed out")
            || message.contains("network connection was lost")
            || message.contains("service unavailable")
    }
}
