import Foundation

struct ChatDTO: Codable, Equatable {
    let id: UUID
    let userId: UUID
    let title: String
    let lastMessageAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case id
        case lastMessageAt = "last_message_at"
        case title
        case updatedAt = "updated_at"
        case userId = "user_id"
    }
}

struct ChatListDTO: Codable, Equatable {
    let items: [ChatDTO]
    let total: Int
}

struct ChatMessageDTO: Codable, Equatable {
    let id: UUID
    let chatId: UUID
    let role: String
    let contentText: String?
    let contentStructured: ChatStructuredContentDTO?
    let aiModel: String?
    let createdAt: Date

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

struct ChatMessageListDTO: Codable, Equatable {
    let items: [ChatMessageDTO]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case hasMore = "has_more"
        case items
    }
}

struct ChatCreateRequestDTO: Encodable, Equatable {
    let title: String
}

struct ChatMessageCreateRequestDTO: Encodable, Equatable {
    let role: String
    let contentText: String?
    let contentStructured: EventActionsContentDTO?
    let images: [ImageAttachmentDTO]?
    let aiModel: String?

    enum CodingKeys: String, CodingKey {
        case aiModel = "ai_model"
        case contentStructured = "content_structured"
        case contentText = "content_text"
        case images
        case role
    }
}

struct ApplyActionsRequestDTO: Encodable, Equatable {
    let acceptedIndices: [Int]

    enum CodingKeys: String, CodingKey {
        case acceptedIndices = "accepted_indices"
    }
}

struct EventSnapshotDTO: Codable, Equatable {
    let title: String
    let startAt: Date
    let endAt: Date?

    enum CodingKeys: String, CodingKey {
        case endAt = "end_at"
        case startAt = "start_at"
        case title
    }
}

struct EventMutationPayloadDTO: Codable, Equatable {
    let title: String?
    let description: String?
    let startAt: Date?
    let endAt: Date?
    let allDay: Bool?
    let type: String?
    let location: String?
    let isFixed: Bool?
    let source: String?

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

struct EventActionDTO: Codable, Equatable {
    let action: String
    let eventId: UUID?
    let eventSnapshot: EventSnapshotDTO?
    let payload: EventMutationPayloadDTO?
    let status: String

    enum CodingKeys: String, CodingKey {
        case action
        case eventId = "event_id"
        case eventSnapshot = "event_snapshot"
        case payload
        case status
    }
}

struct EventActionsContentDTO: Codable, Equatable {
    let type: String
    let actions: [EventActionDTO]
}

struct ImageAttachmentDTO: Codable, Equatable {
    let url: String
    let filename: String
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case url
    }
}

struct ImageMessageContentDTO: Codable, Equatable {
    let type: String
    let images: [ImageAttachmentDTO]
}

struct UploadResponseDTO: Codable, Equatable {
    let url: String
    let filename: String
    let mimeType: String

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case url
    }
}

enum ChatStructuredContentDTO: Codable, Equatable {
    case eventActions(EventActionsContentDTO)
    case imageMessage(ImageMessageContentDTO)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .eventActions(content):
            try content.encode(to: encoder)
        case let .imageMessage(content):
            try content.encode(to: encoder)
        }
    }
}
