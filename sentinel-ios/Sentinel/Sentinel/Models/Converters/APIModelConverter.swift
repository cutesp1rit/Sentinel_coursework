import Foundation

enum APIModelConverter {
    nonisolated static func convert(_ dto: TokenDTO) -> Session {
        Session(accessToken: dto.accessToken, tokenType: dto.tokenType)
    }

    nonisolated static func convert(_ dto: UserDTO) -> User {
        User(
            id: dto.id,
            email: dto.email,
            timezone: dto.timezone,
            locale: dto.locale,
            isVerified: dto.isVerified,
            createdAt: dto.createdAt
        )
    }

    nonisolated static func convert(_ dto: AchievementLevelDTO) -> AchievementLevel {
        AchievementLevel(
            id: dto.id,
            description: dto.description,
            earnedAt: dto.earnedAt,
            icon: dto.icon,
            level: dto.level,
            targetValue: dto.targetValue,
            title: dto.title,
            unlocked: dto.unlocked
        )
    }

    nonisolated static func convert(_ dto: AchievementGroupDTO) -> AchievementGroup {
        AchievementGroup(
            id: dto.groupCode,
            category: dto.category,
            counterName: dto.counterName,
            currentValue: dto.currentValue,
            groupCode: dto.groupCode,
            levels: dto.levels.map(convert)
        )
    }

    nonisolated static func convert(_ dto: EventDTO) -> Event {
        Event(
            id: dto.id,
            userId: dto.userId,
            title: dto.title,
            description: dto.description,
            startAt: dto.startAt,
            endAt: dto.endAt,
            allDay: dto.allDay,
            type: EventKind(rawValue: dto.type) ?? .event,
            location: dto.location,
            isFixed: dto.isFixed,
            source: dto.source,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func convert(_ dto: ChatDTO) -> Chat {
        Chat(
            id: dto.id,
            userId: dto.userId,
            title: dto.title,
            lastMessageAt: dto.lastMessageAt,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }

    nonisolated static func convert(_ dto: EventMutationPayloadDTO) -> EventMutationPayload {
        EventMutationPayload(
            title: dto.title,
            description: dto.description,
            startAt: dto.startAt,
            endAt: dto.endAt,
            allDay: dto.allDay,
            type: dto.type.flatMap(EventKind.init(rawValue:)),
            location: dto.location,
            isFixed: dto.isFixed,
            source: dto.source
        )
    }

    nonisolated static func convert(_ dto: EventSnapshotDTO) -> EventAction.Snapshot {
        EventAction.Snapshot(
            title: dto.title,
            startAt: dto.startAt,
            endAt: dto.endAt
        )
    }

    nonisolated static func convert(_ dto: EventActionDTO) -> EventAction {
        EventAction(
            action: EventAction.Kind(rawValue: dto.action) ?? .create,
            eventId: dto.eventId,
            payload: dto.payload.map(convert),
            status: EventAction.Status(rawValue: dto.status) ?? .pending,
            eventSnapshot: dto.eventSnapshot.map(convert)
        )
    }

    nonisolated static func convert(_ dto: EventActionsContentDTO) -> EventActionsContent {
        EventActionsContent(
            type: dto.type,
            actions: dto.actions.map(convert)
        )
    }

    nonisolated static func convert(_ dto: ImageAttachmentDTO) -> ChatImageAttachment {
        ChatImageAttachment(
            url: dto.url,
            filename: dto.filename,
            mimeType: dto.mimeType,
            previewData: nil
        )
    }

    nonisolated static func convert(_ dto: ChatMessageDTO) -> ChatMessage {
        let role: ChatMessage.Role
        switch dto.role {
        case "assistant": role = .assistant
        case "system": role = .system
        case "tool": role = .tool
        default: role = .user
        }

        return ChatMessage(
            id: dto.id,
            chatId: dto.chatId,
            role: role,
            content: ChatMessage.Content(
                markdownText: dto.contentText,
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
