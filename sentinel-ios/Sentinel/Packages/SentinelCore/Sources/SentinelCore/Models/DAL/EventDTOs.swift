import Foundation

public struct EventDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let userId: UUID
    public let title: String
    public let description: String?
    public let startAt: Date
    public let endAt: Date?
    public let allDay: Bool
    public let type: String
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
        type: String,
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

    enum CodingKeys: String, CodingKey {
        case allDay = "all_day"
        case createdAt = "created_at"
        case description
        case endAt = "end_at"
        case id
        case isFixed = "is_fixed"
        case location
        case source
        case startAt = "start_at"
        case title
        case type
        case updatedAt = "updated_at"
        case userId = "user_id"
    }
}

public struct EventListDTO: Codable, Equatable, Sendable {
    public let items: [EventDTO]
    public let total: Int

    public init(items: [EventDTO], total: Int) {
        self.items = items
        self.total = total
    }
}

public struct EventCreateRequestDTO: Encodable, Equatable, Sendable {
    public let title: String
    public let description: String?
    public let startAt: Date
    public let endAt: Date?
    public let allDay: Bool
    public let type: String
    public let location: String?
    public let isFixed: Bool
    public let source: String

    public init(
        title: String,
        description: String?,
        startAt: Date,
        endAt: Date?,
        allDay: Bool,
        type: String,
        location: String?,
        isFixed: Bool,
        source: String
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

public struct EventUpdateRequestDTO: Encodable, Equatable, Sendable {
    public let title: String?
    public let description: String?
    public let startAt: Date?
    public let endAt: Date?
    public let allDay: Bool?
    public let type: String?
    public let location: String?
    public let isFixed: Bool?

    public init(
        title: String?,
        description: String?,
        startAt: Date?,
        endAt: Date?,
        allDay: Bool?,
        type: String?,
        location: String?,
        isFixed: Bool?
    ) {
        self.title = title
        self.description = description
        self.startAt = startAt
        self.endAt = endAt
        self.allDay = allDay
        self.type = type
        self.location = location
        self.isFixed = isFixed
    }

    enum CodingKeys: String, CodingKey {
        case allDay = "all_day"
        case description
        case endAt = "end_at"
        case isFixed = "is_fixed"
        case location
        case startAt = "start_at"
        case title
        case type
    }
}
