import Foundation

struct ChatListItem: Equatable, Identifiable {
    let id: UUID
    var title: String
    var lastMessageAt: Date?

    init(chat: Chat) {
        id = chat.id
        title = chat.title
        lastMessageAt = chat.lastMessageAt
    }

    var subtitle: String? {
        guard let lastMessageAt else { return nil }
        return lastMessageAt.formatted(date: .abbreviated, time: .shortened)
    }
}
