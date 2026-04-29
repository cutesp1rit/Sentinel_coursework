import Foundation

public struct ChatDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let title: String
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID, userId: UUID, title: String, lastMessageAt: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case id
        case lastMessageAt = "last_message_at"
        case title
        case updatedAt = "updated_at"
        case userId = "user_id"
    }
}

public struct ChatListDTO: Codable, Equatable, Sendable {
    public let items: [ChatDTO]
    public let total: Int

    public init(items: [ChatDTO], total: Int) {
        self.items = items
        self.total = total
    }
}

public struct ChatMessageDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let chatId: UUID
    public let role: String
    public let contentText: String?
    public let contentStructured: ChatStructuredContentDTO?
    public let aiModel: String?
    public let createdAt: Date

    public init(
        id: UUID,
        chatId: UUID,
        role: String,
        contentText: String?,
        contentStructured: ChatStructuredContentDTO?,
        aiModel: String?,
        createdAt: Date
    ) {
        self.id = id
        self.chatId = chatId
        self.role = role
        self.contentText = contentText
        self.contentStructured = contentStructured
        self.aiModel = aiModel
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case aiModel = "ai_model"
        case chatId = "chat_id"
        case contentStructured = "content_structured"
        case contentText = "content_text"
        case createdAt = "created_at"
        case id
        case role
    }
}

public struct ChatMessageListDTO: Codable, Equatable, Sendable {
    public let items: [ChatMessageDTO]
    public let hasMore: Bool

    public init(items: [ChatMessageDTO], hasMore: Bool) {
        self.items = items
        self.hasMore = hasMore
    }

    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case items
    }
}

public struct ChatCreateRequestDTO: Encodable, Equatable, Sendable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct ChatMessageCreateRequestDTO: Encodable, Equatable, Sendable {
    public let role: String
    public let contentText: String?
    public let contentStructured: EventActionsContentDTO?
    public let images: [ImageAttachmentDTO]?
    public let aiModel: String?

    public init(
        role: String,
        contentText: String?,
        contentStructured: EventActionsContentDTO?,
        images: [ImageAttachmentDTO]?,
        aiModel: String?
    ) {
        self.role = role
        self.contentText = contentText
        self.contentStructured = contentStructured
        self.images = images
        self.aiModel = aiModel
    }

    enum CodingKeys: String, CodingKey {
        case aiModel = "ai_model"
        case contentStructured = "content_structured"
        case contentText = "content_text"
        case images
        case role
    }
}

public struct ApplyActionsRequestDTO: Encodable, Equatable, Sendable {
    public let acceptedIndices: [Int]

    public init(acceptedIndices: [Int]) {
        self.acceptedIndices = acceptedIndices
    }

    enum CodingKeys: String, CodingKey {
        case acceptedIndices = "accepted_indices"
    }
}

public struct EventSnapshotDTO: Codable, Equatable, Sendable {
    public let title: String
    public let startAt: Date
    public let endAt: Date?

    public init(title: String, startAt: Date, endAt: Date?) {
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
    }

    enum CodingKeys: String, CodingKey {
        case endAt = "end_at"
        case startAt = "start_at"
        case title
    }
}

public struct EventMutationPayloadDTO: Codable, Equatable, Sendable {
    public let title: String?
    public let description: String?
    public let startAt: Date?
    public let endAt: Date?
    public let allDay: Bool?
    public let type: String?
    public let location: String?
    public let isFixed: Bool?
    public let source: String?

    public init(
        title: String?,
        description: String?,
        startAt: Date?,
        endAt: Date?,
        allDay: Bool?,
        type: String?,
        location: String?,
        isFixed: Bool?,
        source: String?
    ) {
        self.title = title
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.type = type
        self.location = location
        self.isFixed = isFixed
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case allDay = "all_day"
        case description
        case endAt = "end_at"
        case isFixed = "is_fixed"
        case location
        case source
        case startAt = "start_at"
        case title
        case type
    }
}

public struct EventActionDTO: Codable, Equatable, Sendable {
    public let action: String
    public let eventId: UUID?
    public let eventSnapshot: EventSnapshotDTO?
    public let payload: EventMutationPayloadDTO?
    public let status: String

    public init(action: String, eventId: UUID?, eventSnapshot: EventSnapshotDTO?, payload: EventMutationPayloadDTO?, status: String) {
        self.action = action
        self.eventId = eventId
        self.eventSnapshot = eventSnapshot
        self.payload = payload
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case action
        case eventId = "event_id"
        case eventSnapshot = "event_snapshot"
        case payload
        case status
    }
}

public struct EventActionsContentDTO: Codable, Equatable, Sendable {
    public let type: String
    public let actions: [EventActionDTO]

    public init(type: String, actions: [EventActionDTO]) {
        self.type = type
        self.actions = actions
    }
}

public struct ImageAttachmentDTO: Codable, Equatable, Sendable {
    public let url: String
    public let filename: String
    public let mimeType: String

    public init(url: String, filename: String, mimeType: String) {
        self.url = url
        self.filename = filename
        self.mimeType = mimeType
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case url
    }
}

public struct ImageMessageContentDTO: Codable, Equatable, Sendable {
    public let type: String
    public let images: [ImageAttachmentDTO]

    public init(type: String, images: [ImageAttachmentDTO]) {
        self.type = type
        self.images = images
    }
}

public struct UploadResponseDTO: Codable, Equatable, Sendable {
    public let url: String
    public let filename: String
    public let mimeType: String

    public init(url: String, filename: String, mimeType: String) {
        self.url = url
        self.filename = filename
        self.mimeType = mimeType
    }

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case url
    }
}

public enum ChatStructuredContentDTO: Codable, Equatable, Sendable {
    case eventActions(EventActionsContentDTO)
    case imageMessage(ImageMessageContentDTO)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "event_actions":
            self = .eventActions(try EventActionsContentDTO(from: decoder))
        case "image_message":
            self = .imageMessage(try ImageMessageContentDTO(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported structured content type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .eventActions(content):
            try content.encode(to: encoder)
        case let .imageMessage(content):
            try content.encode(to: encoder)
        }
    }
}
