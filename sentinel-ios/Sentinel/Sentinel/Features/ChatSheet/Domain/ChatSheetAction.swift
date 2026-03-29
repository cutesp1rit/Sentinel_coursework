import Foundation

enum ChatSheetAction: Equatable {
    case addAttachmentTapped
    case addSelectedSuggestionsTapped(ChatSheetState.Message.ID)
    case composerFocusChanged(Bool)
    case detentChanged(ChatSheetState.Detent)
    case draftChanged(String)
    case sendButtonTapped
    case toggleSuggestionExpansion(ChatSheetState.Message.ID)
    case toggleSuggestionSelection(
        messageID: ChatSheetState.Message.ID,
        suggestionID: ChatSheetState.Suggestion.ID
    )
}
