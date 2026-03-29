import Foundation

struct EventDTO: Codable, Equatable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let startAt: Date
    let endAt: Date?
    let allDay: Bool
    let type: String
    let location: String?
    let isFixed: Bool
    let source: String
    let createdAt: Date
    let updatedAt: Date

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

struct EventListDTO: Codable, Equatable {
    let items: [EventDTO]
    let total: Int
}
