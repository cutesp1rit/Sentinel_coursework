import ComposableArchitecture
import Foundation

@Reducer
struct ChatSheetReducer {
    var body: some Reducer<ChatSheetState, ChatSheetAction> {
        Reduce { state, action in
            switch action {
            case .addAttachmentTapped:
                if state.detent == .collapsed {
                    state.detent = .medium
                }
                return .none

            case .addSelectedSuggestionsTapped:
                return .none

            case let .composerFocusChanged(isFocused):
                if isFocused {
                    state.detent = .large
                }
                return .none

            case let .detentChanged(detent):
                state.detent = detent
                return .none

            case let .draftChanged(draft):
                state.draft = draft
                return .none

            case .sendButtonTapped:
                if state.detent == .collapsed {
                    state.detent = .medium
                    return .none
                }

                let trimmedDraft = state.draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedDraft.isEmpty else { return .none }

                state.messages.append(.init(role: .user, text: trimmedDraft))
                state.draft = ""
                return .none

            case let .toggleSuggestionExpansion(messageID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }) else {
                    return .none
                }
                guard case var .suggestions(payload) = state.messages[index].content else {
                    return .none
                }

                payload.isExpanded.toggle()
                state.messages[index].content = .suggestions(payload)
                return .none

            case let .toggleSuggestionSelection(messageID, suggestionID):
                guard let index = state.messages.firstIndex(where: { $0.id == messageID }) else {
                    return .none
                }
                guard case var .suggestions(payload) = state.messages[index].content else {
                    return .none
                }

                if payload.selectedSuggestionIDs.contains(suggestionID) {
                    payload.selectedSuggestionIDs.remove(suggestionID)
                } else {
                    payload.selectedSuggestionIDs.insert(suggestionID)
                }

                state.messages[index].content = .suggestions(payload)
                return .none
            }
        }
    }
}
