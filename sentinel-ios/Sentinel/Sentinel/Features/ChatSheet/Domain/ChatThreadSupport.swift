import ComposableArchitecture
import Foundation

extension ChatThreadFeature {
    func sendMessage(state: inout State) -> Effect<Action> {
        guard let accessToken = state.accessToken else {
            state.errorMessage = L10n.ChatSheet.authRequiredBody
            return .none
        }
        guard !state.isSending else { return .none }

        let trimmedDraft = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let composerAttachments = state.composerAttachments
        guard !trimmedDraft.isEmpty || !composerAttachments.isEmpty else { return .none }

        let pendingLocalMessageID = UUID()
        let requestID = UUID()
        let existingActiveChatID = state.activeChatID
        state.isSending = true
        state.errorMessage = nil
        state.activeSendRequestID = requestID
        state.pendingLocalMessageID = pendingLocalMessageID
        state.sendStage = .delivering
        state.messages.append(.init(id: pendingLocalMessageID, role: .user, text: trimmedDraft, images: composerAttachments.map(\.imageAttachment), deliveryState: .sending))
        state.shouldAutoScrollToBottom = true
        state.draft = ""
        state.composerAttachments = []

        return .run { [chatClient] send in
            var activeChatID = existingActiveChatID
            var uploadedImages: [ChatImageAttachment] = []
            do {
                if activeChatID == nil {
                    let createdChat = try await chatClient.createChat(Self.chatTitle(from: trimmedDraft), accessToken)
                    activeChatID = createdChat.id
                }

                for attachment in composerAttachments {
                    let image = try await chatClient.uploadImage(activeChatID!, attachment.filename, attachment.mimeType, attachment.data, accessToken)
                    uploadedImages.append(
                        ChatImageAttachment(
                            url: image.url,
                            filename: image.filename,
                            mimeType: image.mimeType,
                            previewData: attachment.previewData ?? attachment.data
                        )
                    )
                }

                let assistantMessage = try await chatClient.sendMessage(activeChatID!, "user", trimmedDraft.isEmpty ? nil : trimmedDraft, uploadedImages, accessToken)
                await send(.sendResponseReceived(requestID: requestID, activeChatID: activeChatID!, assistantMessage: assistantMessage, requestToken: accessToken))
                await send(.sendStageChanged(.syncing, requestID: requestID))
                let chats = try await chatClient.listChats(accessToken)
                let (messages, hasMore) = try await chatClient.listMessages(activeChatID!, nil, Constants.pageSize, accessToken)
                await send(.sendFlowCompleted(requestID: requestID, chats: chats, activeChatID: activeChatID!, messages: messages, assistantMessage: assistantMessage, hasMore: hasMore, requestToken: accessToken))
            } catch {
                await send(.sendFlowFailed(
                    requestID: requestID,
                    message: Self.errorMessage(for: error),
                    restoreDraft: trimmedDraft,
                    restoreAttachments: composerAttachments,
                    activeChatID: activeChatID,
                    messages: nil,
                    hasMore: nil,
                    messagePersisted: false,
                    requestToken: accessToken
                ))
            }
        }
    }

    func applySuggestions(state: inout State, messageID: ChatThreadMessage.ID) -> Effect<Action> {
        guard let accessToken = state.accessToken,
              let activeChatID = state.activeChatID,
              let index = state.messages.firstIndex(where: { $0.id == messageID }),
              var payload = state.messages[index].suggestionsPayload,
              let applyPlan = payload.applyingSelectionPlan() else { return .none }

        payload.isApplying = true
        state.messages[index].suggestionsPayload = payload
        state.errorMessage = nil

        return .run { [calendarSyncClient, chatClient, eventsClient, localNotificationsClient] send in
            do {
                let updatedMessage = try await chatClient.applyActions(activeChatID, messageID, applyPlan.acceptedIndices, accessToken)
                var canonicalEventsByID: [UUID: Event] = [:]

                if let syncRange = applyPlan.syncRange {
                    let rangedEvents = try await eventsClient.listEvents(syncRange.lowerBound, syncRange.upperBound, accessToken)
                    canonicalEventsByID = Dictionary(uniqueKeysWithValues: rangedEvents.map { ($0.id, $0) })
                }

                for eventID in applyPlan.upsertEventIDs where !canonicalEventsByID.keys.contains(eventID) {
                    canonicalEventsByID[eventID] = try await eventsClient.getEvent(eventID, accessToken)
                }

                if !canonicalEventsByID.isEmpty || !applyPlan.deletedEventIDs.isEmpty {
                    _ = try await calendarSyncClient.sync(.init(deletedEventIDs: applyPlan.deletedEventIDs, events: Array(canonicalEventsByID.values)))
                }

                await localNotificationsClient.syncReminderNotifications(Array(canonicalEventsByID.values), applyPlan.deletedEventIDs)
                await send(.suggestionApplyCompleted(messageID: messageID, updatedMessage: updatedMessage, requestToken: accessToken))
            } catch {
                await send(.suggestionApplyFailed(messageID: messageID, message: Self.errorMessage(for: error), requestToken: accessToken))
            }
        }
    }

    static func chatTitle(from draft: String) -> String {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return L10n.ChatSheet.newChat }
        return String(trimmed.replacingOccurrences(of: "\n", with: " ").prefix(48))
    }

    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }

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
                mimeType: image.mimeType,
                previewData: image.previewData ?? previewDataByFilename[image.filename] ?? nil
            )
        }
        return mergedMessage
    }

    static func refreshConflictEffects(for messages: [ChatThreadMessage]) -> Effect<Action> {
        .merge(
            messages.compactMap { message in
                guard let payload = message.suggestionsPayload, !payload.conflictDrafts.isEmpty else { return nil }
                return .send(.refreshSuggestionConflictsRequested(message.id))
            }
        )
    }
}
