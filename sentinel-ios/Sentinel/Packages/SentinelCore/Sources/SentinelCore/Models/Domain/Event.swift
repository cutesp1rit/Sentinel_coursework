import Foundation

public enum EventKind: String, Equatable, Sendable {
    case event
    case reminder
}

public struct Event: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let title: String
    public let description: String?
    public let startAt: Date
    public let endAt: Date?
    public let allDay: Bool
    public let type: EventKind
    public let location: String?
    public let isFixed: Bool
    public let source: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        userId: UUID,
        title: String,
        description: String?,
        startAt: Date,
        endAt: Date?,
        allDay: Bool,
        type: EventKind,
        location: String?,
        isFixed: Bool,
        source: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.type = type
        self.location = location
        self.isFixed = isFixed
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
