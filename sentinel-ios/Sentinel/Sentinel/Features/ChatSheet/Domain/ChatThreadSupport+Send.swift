import ComposableArchitecture
import SentinelCore
import Foundation

extension ChatThreadFeature {
    func sendMessage(state: inout State) -> Effect<Action> {
        sendMessage(
            state: &state,
            draft: state.draft,
            attachments: state.composerAttachments,
            localMessageID: nil
        )
    }

    func retryFailedMessage(state: inout State, messageID: ChatThreadMessage.ID) -> Effect<Action> {
        guard let message = state.messages.first(where: { $0.id == messageID }),
              message.isFailedToSend else { return .none }

        return sendMessage(
            state: &state,
            draft: message.markdownText ?? "",
            attachments: message.failedComposerAttachments,
            localMessageID: messageID
        )
    }

    private func sendMessage(
        state: inout State,
        draft: String,
        attachments: [ChatComposerAttachment],
        localMessageID: ChatThreadMessage.ID?
    ) -> Effect<Action> {
        guard let accessToken = state.accessToken else {
            state.errorMessage = L10n.ChatSheet.authRequiredBody
            return .none
        }
        guard !state.isSending else { return .none }

        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let composerAttachments = attachments
        guard !trimmedDraft.isEmpty || !composerAttachments.isEmpty else { return .none }

        let pendingLocalMessageID = localMessageID ?? UUID()
        let requestID = UUID()
        let existingActiveChatID = state.activeChatID
        state.isSending = true
        state.errorMessage = nil
        state.activeSendRequestID = requestID
        state.pendingLocalMessageID = pendingLocalMessageID
        state.sendStage = .delivering
        if let localMessageID,
           let index = state.messages.firstIndex(where: { $0.id == localMessageID }) {
            state.messages[index].deliveryState = .sending
        } else {
            state.messages.append(
                .init(
                    id: pendingLocalMessageID,
                    role: .user,
                    text: trimmedDraft,
                    images: composerAttachments.map(\.imageAttachment),
                    deliveryState: .sending
                )
            )
        }
        state.shouldAutoScrollToBottom = true
        if localMessageID == nil {
            state.draft = ""
            state.composerAttachments = []
        }

        return .run { [appSettingsClient, chatClient] send in
            var activeChatID = existingActiveChatID
            var uploadedImages: [ChatImageAttachment] = []
            do {
                let settings = await appSettingsClient.load()
                let contentText = DefaultPromptEnvelope.applying(
                    prompt: settings.defaultPromptTemplate,
                    to: trimmedDraft.isEmpty ? nil : trimmedDraft
                )

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
                            localData: nil,
                            mimeType: image.mimeType,
                            previewData: attachment.previewData ?? attachment.data
                        )
                    )
                }

                let assistantMessage = try await chatClient.sendMessage(
                    activeChatID!,
                    "user",
                    contentText,
                    uploadedImages,
                    accessToken
                )
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
}
