import Foundation

extension APIModelConverter {
    public nonisolated static func convert(_ dto: ChatDTO) -> Chat {
        Chat(
            id: dto.id,
            userId: dto.userId,
            title: dto.title,
            lastMessageAt: dto.lastMessageAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    public nonisolated static func convert(_ dto: ImageAttachmentDTO) -> ChatImageAttachment {
        ChatImageAttachment(
            url: dto.url,
            filename: dto.filename,
            localData: nil,
            mimeType: dto.mimeType,
            previewData: nil
        )
    }

    public nonisolated static func convert(_ dto: ChatMessageDTO) -> ChatMessage {
        let isUserRole: Bool
        let role: ChatMessage.Role
        switch dto.role {
        case "assistant":
            isUserRole = false
            role = .assistant
        case "system":
            isUserRole = false
            role = .system
        case "tool":
            isUserRole = false
            role = .tool
        default:
            isUserRole = true
            role = .user
        }

        return ChatMessage(
            id: dto.id,
            chatId: dto.chatId,
            role: role,
            content: ChatMessage.Content(
                markdownText: isUserRole
                    ? DefaultPromptEnvelope.displayText(from: dto.contentText)
                    : dto.contentText,
                eventActions: dto.contentStructured?.eventActionsDTO.map(convert),
                images: dto.contentStructured?.imageMessageDTO?.images.map(convert) ?? []
            ),
            aiModel: dto.aiModel,
            createdAt: dto.createdAt
        )
    }
}

private extension ChatStructuredContentDTO {
    nonisolated var eventActionsDTO: EventActionsContentDTO? {
        guard case let .eventActions(content) = self else { return nil }
        return content
    }

    nonisolated var imageMessageDTO: ImageMessageContentDTO? {
        guard case let .imageMessage(content) = self else { return nil }
        return content
    }
}
