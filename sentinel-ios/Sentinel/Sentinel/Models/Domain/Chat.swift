import Foundation

struct Chat: Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let lastMessageAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

struct ChatMessage: Equatable, Identifiable {
    enum Role: Equatable {
        case assistant
        case system
        case tool
        case user
    }

    struct Content: Equatable {
        var markdownText: String?
        var eventActions: EventActionsContent?

        var isEmpty: Bool {
            markdownText == nil && eventActions == nil
        }
    }

    let id: UUID
    let chatId: UUID
    let role: Role
    let content: Content
    let aiModel: String?
    let createdAt: Date
}

struct EventAction: Equatable {
    enum Kind: String, Equatable {
        case create
        case delete
        case update
    }

    enum Status: String, Equatable {
        case accepted
        case pending
        case rejected
    }

    let action: Kind
    let eventId: UUID?
    let payload: EventMutationPayload?
    let status: Status
}

struct EventActionsContent: Equatable {
    let type: String
    let actions: [EventAction]
}

struct EventMutationPayload: Equatable {
    let title: String?
    let description: String?
    let startAt: Date?
    let endAt: Date?
    let allDay: Bool?
    let type: EventKind?
    let location: String?
    let isFixed: Bool?
    let source: String?
}
