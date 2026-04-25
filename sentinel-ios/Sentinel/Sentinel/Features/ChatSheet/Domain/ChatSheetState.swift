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

    struct ComposerAttachment: Equatable, Identifiable {
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
            var isApplying = false
            var suggestions: [Suggestion]
            var isExpanded = true
            var selectedSuggestionIDs: Set<Suggestion.ID> = []
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
            self.markdownText = text
            self.suggestionsPayload = nil
        }

        init(
            id: UUID = UUID(),
            role: Role,
            suggestions: [Suggestion],
            isApplying: Bool = false,
            isExpanded: Bool = true,
            selectedSuggestionIDs: Set<Suggestion.ID> = []
        ) {
            self.id = id
            self.role = role
            self.deliveryState = .delivered
            self.images = []
            self.markdownText = nil
            self.suggestionsPayload = .init(
                isApplying: isApplying,
                suggestions: suggestions,
                isExpanded: isExpanded,
                selectedSuggestionIDs: selectedSuggestionIDs
            )
        }

        init(chatMessage: ChatMessage) {
            id = chatMessage.id
            role = chatMessage.role == .user ? .user : .assistant
            deliveryState = .delivered
            images = chatMessage.content.images
            markdownText = chatMessage.content.markdownText
            suggestionsPayload = chatMessage.content.eventActions.map(SuggestionsPayload.init)
        }

        var isUser: Bool {
            role == .user
        }
    }

    struct Suggestion: Equatable, Identifiable {
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

        init(
            id: String,
            action: EventAction.Kind,
            actionIndex: Int,
            allDay: Bool,
            eventId: UUID?,
            eventKind: EventKind,
            endAt: Date?,
            startAt: Date?,
            status: EventAction.Status,
            title: String,
            timeRange: String,
            location: String,
            hasConflict: Bool
        ) {
            self.id = id
            self.action = action
            self.actionIndex = actionIndex
            self.allDay = allDay
            self.eventId = eventId
            self.eventKind = eventKind
            self.endAt = endAt
            self.startAt = startAt
            self.status = status
            self.title = title
            self.timeRange = timeRange
            self.location = location
            self.hasConflict = hasConflict
        }

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
    }

    var accessToken: String?
    var activeChatID: UUID?
    var chatSummaries: [ChatSummary] = []
    var composerAttachments: [ComposerAttachment] = []
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
    var activeSendRequestID: UUID?
    var pendingLocalMessageID: Message.ID?
    var sendStage: SendStage?
    var shouldAutoScrollToBottom = false

    init(
        accessToken: String? = nil,
        activeChatID: UUID? = nil,
        chatSummaries: [ChatSummary] = [],
        composerAttachments: [ComposerAttachment] = [],
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
        activeSendRequestID: UUID? = nil,
        pendingLocalMessageID: Message.ID? = nil,
        sendStage: SendStage? = nil,
        shouldAutoScrollToBottom: Bool = false
    ) {
        self.accessToken = accessToken
        self.activeChatID = activeChatID
        self.chatSummaries = chatSummaries
        self.composerAttachments = composerAttachments
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
        self.activeSendRequestID = activeSendRequestID
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
        self.init(
            suggestions: eventActionsContent.actions.enumerated().map { actionIndex, action in
                ChatSheetState.Suggestion(actionIndex: actionIndex, action: action)
            }
        )
    }
}
