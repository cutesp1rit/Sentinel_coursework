import Foundation

public struct Chat: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let title: String
    public let lastMessageAt: Date?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        userId: UUID,
        title: String,
        lastMessageAt: Date?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.lastMessageAt = lastMessageAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ChatImageAttachment: Equatable, Identifiable, Sendable {
    public let url: String
    public let filename: String
    public let localData: Data?
    public let mimeType: String
    public let previewData: Data?

    public var id: String {
        url.isEmpty ? "local-\(filename)" : url
    }

    public init(
        url: String,
        filename: String,
        localData: Data?,
        mimeType: String,
        previewData: Data?
    ) {
        self.url = url
        self.filename = filename
        self.localData = localData
        self.mimeType = mimeType
        self.previewData = previewData
    }
}

public struct ChatMessage: Equatable, Identifiable, Sendable {
    public enum Role: Equatable, Sendable {
        case assistant
        case system
        case tool
        case user
    }

    public struct Content: Equatable, Sendable {
        public var markdownText: String?
        public var eventActions: EventActionsContent?
        public var images: [ChatImageAttachment] = []

        public var isEmpty: Bool {
            markdownText == nil && eventActions == nil && images.isEmpty
        }

        public init(
            markdownText: String? = nil,
            eventActions: EventActionsContent? = nil,
            images: [ChatImageAttachment] = []
        ) {
            self.markdownText = markdownText
            self.eventActions = eventActions
            self.images = images
        }
    }

    public let id: UUID
    public let chatId: UUID
    public let role: Role
    public let content: Content
    public let aiModel: String?
    public let createdAt: Date

    public init(
        id: UUID,
        chatId: UUID,
        role: Role,
        content: Content,
        aiModel: String?,
        createdAt: Date
    ) {
        self.id = id
        self.chatId = chatId
        self.role = role
        self.content = content
        self.aiModel = aiModel
        self.createdAt = createdAt
    }
}

public struct EventAction: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case create
        case delete
        case update
    }

    public enum Status: String, Equatable, Sendable {
        case accepted
        case pending
        case rejected
    }

    public struct Snapshot: Equatable, Sendable {
        public let title: String
        public let startAt: Date
        public let endAt: Date?

        public init(title: String, startAt: Date, endAt: Date?) {
            self.title = title
            self.startAt = startAt
            self.endAt = endAt
        }
    }

    public let action: Kind
    public let eventId: UUID?
    public let payload: EventMutationPayload?
    public let status: Status
    public let eventSnapshot: Snapshot?

    public init(
        action: Kind,
        eventId: UUID?,
        payload: EventMutationPayload?,
        status: Status,
        eventSnapshot: Snapshot?
    ) {
        self.action = action
        self.eventId = eventId
        self.payload = payload
        self.status = status
        self.eventSnapshot = eventSnapshot
    }
}

public struct EventActionsContent: Equatable, Sendable {
    public let type: String
    public let actions: [EventAction]

    public init(type: String, actions: [EventAction]) {
        self.type = type
        self.actions = actions
    }
}

public struct EventMutationPayload: Equatable, Sendable {
    public let title: String?
    public let description: String?
    public let startAt: Date?
    public let endAt: Date?
    public let allDay: Bool?
    public let type: EventKind?
    public let location: String?
    public let isFixed: Bool?
    public let source: String?

    public init(
        title: String?,
        description: String?,
        startAt: Date?,
        endAt: Date?,
        allDay: Bool?,
        type: EventKind?,
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
}
