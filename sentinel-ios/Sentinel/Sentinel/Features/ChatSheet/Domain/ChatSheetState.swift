import ComposableArchitecture
import Foundation

@ObservableState
struct ChatSheetState: Equatable {
    enum Detent: Equatable {
        case collapsed
        case medium
        case large
    }

    enum SendStage: Equatable {
        case delivering
        case syncing

        var progressValue: Double {
            switch self {
            case .delivering:
                return 0.42
            case .syncing:
                return 0.84
            }
        }
    }

    struct ChatSummary: Equatable, Identifiable {
        let id: UUID
        var title: String
        var lastMessageAt: Date?

        init(chat: Chat) {
            id = chat.id
            title = chat.title
            lastMessageAt = chat.lastMessageAt
        }
    }

    struct Message: Equatable, Identifiable {
        enum Role: Equatable {
            case user
            case assistant
        }

        enum DeliveryState: Equatable {
            case delivered
            case sending
        }

        struct SuggestionsPayload: Equatable {
            var suggestions: [Suggestion]
            var isExpanded = true
            var selectedSuggestionIDs: Set<Suggestion.ID> = []
        }

        let id: UUID
        let role: Role
        var deliveryState: DeliveryState
        var markdownText: String?
        var suggestionsPayload: SuggestionsPayload?

        init(
            id: UUID = UUID(),
            role: Role,
            text: String,
            deliveryState: DeliveryState = .delivered
        ) {
            self.id = id
            self.role = role
            self.deliveryState = deliveryState
            self.markdownText = text
            self.suggestionsPayload = nil
        }

        init(
            id: UUID = UUID(),
            role: Role,
            suggestions: [Suggestion],
            isExpanded: Bool = true,
            selectedSuggestionIDs: Set<Suggestion.ID> = []
        ) {
            self.id = id
            self.role = role
            self.deliveryState = .delivered
            self.markdownText = nil
            self.suggestionsPayload = .init(
                suggestions: suggestions,
                isExpanded: isExpanded,
                selectedSuggestionIDs: selectedSuggestionIDs
            )
        }

        init(chatMessage: ChatMessage) {
            id = chatMessage.id
            role = chatMessage.role == .user ? .user : .assistant
            deliveryState = .delivered
            markdownText = chatMessage.content.markdownText
            suggestionsPayload = chatMessage.content.eventActions.map(SuggestionsPayload.init)
        }

        var isUser: Bool {
            role == .user
        }
    }

    struct Suggestion: Equatable, Identifiable {
        let id: UUID
        var title: String
        var timeRange: String
        var location: String
        var hasConflict: Bool

        init(
            id: UUID = UUID(),
            title: String,
            timeRange: String,
            location: String,
            hasConflict: Bool
        ) {
            self.id = id
            self.title = title
            self.timeRange = timeRange
            self.location = location
            self.hasConflict = hasConflict
        }

        init(action: EventAction) {
            id = UUID()
            title = Self.title(for: action)
            timeRange = Self.timeRange(for: action)
            location = Self.location(for: action)
            hasConflict = false
        }

        private static func title(for action: EventAction) -> String {
            if let title = action.payload?.title, !title.isEmpty {
                return title
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
            let start = action.payload?.startAt
            let end = action.payload?.endAt

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
                return "Update proposal"
            case .delete:
                return "Delete proposal"
            }
        }
    }

    var accessToken: String?
    var activeChatID: UUID?
    var chatSummaries: [ChatSummary] = []
    var draft = ""
    var detent: Detent = .collapsed
    var errorMessage: String?
    var hasLoadedChats = false
    var hasMoreHistory = false
    var isChatListPresented = false
    var isLoadingChats = false
    var isLoadingMessages = false
    var isLoadingMoreHistory = false
    var isSending = false
    var messages: [Message] = []
    var pendingLocalMessageID: Message.ID?
    var sendStage: SendStage?
    var shouldAutoScrollToBottom = false

    init(
        accessToken: String? = nil,
        activeChatID: UUID? = nil,
        chatSummaries: [ChatSummary] = [],
        draft: String = "",
        detent: Detent = .collapsed,
        errorMessage: String? = nil,
        hasLoadedChats: Bool = false,
        hasMoreHistory: Bool = false,
        isChatListPresented: Bool = false,
        isLoadingChats: Bool = false,
        isLoadingMessages: Bool = false,
        isLoadingMoreHistory: Bool = false,
        isSending: Bool = false,
        messages: [Message] = [],
        pendingLocalMessageID: Message.ID? = nil,
        sendStage: SendStage? = nil,
        shouldAutoScrollToBottom: Bool = false
    ) {
        self.accessToken = accessToken
        self.activeChatID = activeChatID
        self.chatSummaries = chatSummaries
        self.draft = draft
        self.detent = detent
        self.errorMessage = errorMessage
        self.hasLoadedChats = hasLoadedChats
        self.hasMoreHistory = hasMoreHistory
        self.isChatListPresented = isChatListPresented
        self.isLoadingChats = isLoadingChats
        self.isLoadingMessages = isLoadingMessages
        self.isLoadingMoreHistory = isLoadingMoreHistory
        self.isSending = isSending
        self.messages = messages
        self.pendingLocalMessageID = pendingLocalMessageID
        self.sendStage = sendStage
        self.shouldAutoScrollToBottom = shouldAutoScrollToBottom
    }

    var activeChatTitle: String {
        guard let activeChatID else {
            return L10n.ChatSheet.newChat
        }

        return chatSummaries.first(where: { $0.id == activeChatID })?.title
            ?? L10n.ChatSheet.newChat
    }

    var isSignedIn: Bool {
        accessToken != nil
    }

    static let initial = Self()
}

private extension ChatSheetState.Message.SuggestionsPayload {
    init(eventActionsContent: EventActionsContent) {
        self.init(suggestions: eventActionsContent.actions.map(ChatSheetState.Suggestion.init))
    }
}
