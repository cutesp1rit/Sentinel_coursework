import ComposableArchitecture
import SentinelCore
import Foundation

@CasePathable
enum ChatSheetAction: Equatable {
    case accessTokenChanged(String?)
    case chatListButtonTapped
    case chatListPresentationChanged(Bool)
    case detentChanged(ChatSheetState.Detent)
    case list(ChatListFeature.Action)
    case sheetPresented
    case thread(ChatThreadFeature.Action)
    case delegate(ChatSheetDelegate)
}

enum ChatSheetDelegate: Equatable {
    case suggestionApplyCompleted
}
