import Foundation
import SwiftUI

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

struct ChatComposerAttachment: Equatable, Identifiable {
    let id: UUID
    let data: Data
    let filename: String
    let mimeType: String

    init(
        id: UUID = UUID(),
        data: Data,
        filename: String,
        mimeType: String
    ) {
        self.id = id
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
    }

    var imageAttachment: ChatImageAttachment {
        ChatImageAttachment(
            url: "",
            filename: filename,
            mimeType: mimeType,
            previewData: data
        )
    }
}

struct ChatSuggestion: Equatable, Identifiable {
    let id: String
    let action: EventAction.Kind
    let actionIndex: Int
    let allDay: Bool
    let eventId: UUID?
    let eventKind: EventKind
    let endAt: Date?
    let startAt: Date?
    let status: EventAction.Status
    var title: String
    var timeRange: String
    var location: String
    var hasConflict: Bool

    init(actionIndex: Int, action: EventAction) {
        let resolvedStartAt = action.payload?.startAt ?? action.eventSnapshot?.startAt
        let resolvedEndAt = action.payload?.endAt ?? action.eventSnapshot?.endAt

        self.action = action.action
        self.actionIndex = actionIndex
        allDay = action.payload?.allDay ?? false
        eventId = action.eventId
        eventKind = action.payload?.type ?? .event
        endAt = resolvedEndAt
        startAt = resolvedStartAt
        status = action.status
        id = Self.stableID(actionIndex: actionIndex, action: action)
        title = Self.title(for: action)
        timeRange = Self.timeRange(for: action)
        location = Self.location(for: action)
        hasConflict = false
    }

    private static func title(for action: EventAction) -> String {
        if let title = action.payload?.title, !title.isEmpty {
            return title
        }
        if let snapshotTitle = action.eventSnapshot?.title, !snapshotTitle.isEmpty {
            return snapshotTitle
        }

        switch action.action {
        case .create:
            return "Create Event"
        case .update:
            return "Update Event"
        case .delete:
            return "Delete Event"
        }
    }

    private static func timeRange(for action: EventAction) -> String {
        let start = action.payload?.startAt ?? action.eventSnapshot?.startAt
        let end = action.payload?.endAt ?? action.eventSnapshot?.endAt

        switch (start, end) {
        case let (start?, end?):
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return start.formatted(date: .abbreviated, time: .shortened)
        default:
            return action.status.rawValue.capitalized
        }
    }

    private static func location(for action: EventAction) -> String {
        if let location = action.payload?.location, !location.isEmpty {
            return location
        }

        switch action.action {
        case .create:
            return "Create proposal"
        case .update:
            return action.eventSnapshot?.title ?? "Update proposal"
        case .delete:
            return action.eventSnapshot?.title ?? "Delete proposal"
        }
    }

    private static func stableID(actionIndex: Int, action: EventAction) -> String {
        if let eventId = action.eventId {
            return "event-\(eventId.uuidString)-\(actionIndex)"
        }
        return "proposal-\(actionIndex)"
    }

    var statusText: String? {
        switch status {
        case .accepted:
            return L10n.ChatSheet.statusAccepted
        case .pending:
            return nil
        case .rejected:
            return L10n.ChatSheet.statusRejected
        }
    }

    var statusTint: Color {
        switch status {
        case .accepted:
            return .green
        case .pending, .rejected:
            return .secondary
        }
    }
}

struct ChatThreadMessage: Equatable, Identifiable {
    enum Role: Equatable {
        case user
        case assistant
    }

    enum DeliveryState: Equatable {
        case delivered
        case sending
    }

    struct SuggestionsPayload: Equatable {
        var isApplying = false
        var suggestions: [ChatSuggestion]
        var isExpanded = true
        var selectedSuggestionIDs: Set<ChatSuggestion.ID> = []
    }

    let id: UUID
    let role: Role
    var deliveryState: DeliveryState
    var images: [ChatImageAttachment]
    var markdownText: String?
    var suggestionsPayload: SuggestionsPayload?

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        images: [ChatImageAttachment] = [],
        deliveryState: DeliveryState = .delivered
    ) {
        self.id = id
        self.role = role
        self.deliveryState = deliveryState
        self.images = images
        markdownText = text
        suggestionsPayload = nil
    }

    init(chatMessage: ChatMessage) {
        id = chatMessage.id
        role = chatMessage.role == .user ? .user : .assistant
        deliveryState = .delivered
        images = chatMessage.content.images
        markdownText = chatMessage.content.markdownText
        suggestionsPayload = chatMessage.content.eventActions.map { eventActions in
            .init(
                suggestions: eventActions.actions.enumerated().map { index, action in
                    ChatSuggestion(actionIndex: index, action: action)
                }
            )
        }
    }

    var isUser: Bool {
        role == .user
    }

    var hasBubbleContent: Bool {
        markdownText != nil || !images.isEmpty
    }
}

enum ChatSendStage: Equatable {
    case delivering
    case syncing
}

extension ChatThreadMessage.SuggestionsPayload {
    func isSelected(_ suggestionID: ChatSuggestion.ID) -> Bool {
        selectedSuggestionIDs.contains(suggestionID)
    }

    var selectedPendingCount: Int {
        suggestions.filter {
            selectedSuggestionIDs.contains($0.id) && $0.status == .pending
        }.count
    }

    var isSingleSuggestion: Bool {
        suggestions.count == 1
    }

    var addToCalendarTitle: String {
        if isApplying {
            return L10n.ChatSheet.syncingToCalendar
        }
        if !hasPendingSuggestions {
            return L10n.ChatSheet.applied
        }
        if suggestions.count == 1 || selectedPendingCount == 0 {
            return L10n.ChatSheet.addToCalendar
        }
        return L10n.ChatSheet.addCountToCalendar(selectedPendingCount)
    }

    var canAddToCalendar: Bool {
        guard !isApplying, hasPendingSuggestions else {
            return false
        }
        let pendingSuggestions = suggestions.filter { $0.status == .pending }
        return pendingSuggestions.count == 1 || selectedPendingCount > 0
    }
}

extension Array where Element == ChatThreadMessage {
    func spacing(after index: Int) -> CGFloat {
        guard indices.contains(index + 1) else { return 0 }
        return self[index].role == self[index + 1].role ? AppSpacing.small : AppSpacing.medium
    }
}
