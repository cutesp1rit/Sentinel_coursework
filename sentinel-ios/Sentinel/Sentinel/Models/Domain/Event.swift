import Foundation

enum EventKind: String, Equatable {
    case event
    case reminder
}

struct Event: Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let startAt: Date
    let endAt: Date?
    let allDay: Bool
    let type: EventKind
    let location: String?
    let isFixed: Bool
    let source: String
    let createdAt: Date
    let updatedAt: Date
}
