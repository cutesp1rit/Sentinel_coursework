import ComposableArchitecture
import Foundation

@ObservableState
struct ChatSheetState: Equatable {
    enum Detent: Equatable {
        case collapsed
        case medium
        case large
    }

    struct Message: Equatable, Identifiable {
        enum Role: Equatable {
            case user
            case assistant
        }

        struct SuggestionsPayload: Equatable {
            var suggestions: [Suggestion]
            var isExpanded = true
            var selectedSuggestionIDs: Set<Suggestion.ID> = []
        }

        enum Content: Equatable {
            case markdown(String)
            case suggestions(SuggestionsPayload)
        }

        let id: UUID
        let role: Role
        var content: Content

        init(id: UUID = UUID(), role: Role, text: String) {
            self.id = id
            self.role = role
            self.content = .markdown(text)
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
            self.content = .suggestions(
                .init(
                    suggestions: suggestions,
                    isExpanded: isExpanded,
                    selectedSuggestionIDs: selectedSuggestionIDs
                )
            )
        }

        var isUser: Bool {
            role == .user
        }

        var markdownText: String? {
            guard case let .markdown(text) = content else { return nil }
            return text
        }

        var suggestionsPayload: SuggestionsPayload? {
            guard case let .suggestions(payload) = content else { return nil }
            return payload
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
    }

    var draft = ""
    var detent: Detent = .collapsed
    var messages: [Message]

    init(
        draft: String = "",
        detent: Detent = .collapsed,
        messages: [Message] = []
    ) {
        self.draft = draft
        self.detent = detent
        self.messages = messages
    }

    private static let sampleSuggestions = [
        Suggestion(
            title: L10n.ChatSheet.Mock.suggestionOneTitle,
            timeRange: L10n.ChatSheet.Mock.suggestionOneTimeRange,
            location: L10n.ChatSheet.Mock.suggestionOneLocation,
            hasConflict: false
        ),
        Suggestion(
            title: L10n.ChatSheet.Mock.suggestionTwoTitle,
            timeRange: L10n.ChatSheet.Mock.suggestionTwoTimeRange,
            location: L10n.ChatSheet.Mock.suggestionTwoLocation,
            hasConflict: false
        ),
        Suggestion(
            title: L10n.ChatSheet.Mock.suggestionThreeTitle,
            timeRange: L10n.ChatSheet.Mock.suggestionThreeTimeRange,
            location: L10n.ChatSheet.Mock.suggestionThreeLocation,
            hasConflict: true
        )
    ]

    private static let sampleMessages = [
        Message(role: .user, text: L10n.ChatSheet.Mock.messageOne),
        Message(role: .assistant, text: L10n.ChatSheet.Mock.messageTwo),
        Message(role: .user, text: L10n.ChatSheet.Mock.messageThree),
        Message(
            role: .assistant,
            suggestions: sampleSuggestions,
            isExpanded: true,
            selectedSuggestionIDs: [sampleSuggestions[0].id]
        )
    ]

    static let initial = Self(
        draft: "",
        detent: .collapsed,
        messages: sampleMessages
    )
}
