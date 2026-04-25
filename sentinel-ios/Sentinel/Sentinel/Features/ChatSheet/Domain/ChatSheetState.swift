import ComposableArchitecture
import Foundation

@ObservableState
struct ChatSheetState: Equatable {
    enum Detent: Equatable {
        case collapsed
        case medium
        case large
    }

    var detent: Detent = .collapsed
    var isChatListPresented = false
    var list = ChatListFeature.State()
    var thread = ChatThreadFeature.State()

    var activeChatTitle: String {
        list.activeChatTitle
    }

    var isSignedIn: Bool {
        thread.isSignedIn
    }

    static let initial = Self()
}
