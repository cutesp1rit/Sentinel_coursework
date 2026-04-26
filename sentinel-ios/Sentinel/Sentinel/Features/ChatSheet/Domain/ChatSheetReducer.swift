import ComposableArchitecture

@Reducer
struct ChatSheetReducer {
    var body: some Reducer<ChatSheetState, ChatSheetAction> {
        Scope(state: \.list, action: \.list) {
            ChatListFeature()
        }

        Scope(state: \.thread, action: \.thread) {
            ChatThreadFeature()
        }

        Reduce { state, action in
            switch action {
            case let .accessTokenChanged(token):
                state.isChatListPresented = false
                return .merge(
                    .send(.list(.accessTokenChanged(token))),
                    .send(.thread(.accessTokenChanged(token)))
                )

            case .chatListButtonTapped:
                guard state.isSignedIn else { return .none }
                state.isChatListPresented = true
                return .none

            case let .chatListPresentationChanged(isPresented):
                state.isChatListPresented = isPresented
                return .none

            case let .detentChanged(detent):
                state.detent = detent
                if detent == .collapsed {
                    state.isChatListPresented = false
                }
                return .none

            case let .list(.delegate(.activeChatChanged(chatID))):
                state.isChatListPresented = false
                return .merge(
                    .send(.thread(.activeChatChanged(chatID))),
                    .send(.list(.activeChatChanged(chatID)))
                )

            case let .thread(.delegate(.chatActivated(chatID))):
                return .send(.list(.activeChatChanged(chatID)))

            case let .thread(.delegate(.chatListShouldReload(chatID))):
                return .send(.list(.reload(preferredActiveChatID: chatID)))

            case .thread(.delegate(.expandRequested)):
                if state.detent == .collapsed {
                    state.detent = .large
                }
                return .none

            case .thread(.delegate(.suggestionsApplied)):
                return .send(.delegate(.suggestionApplyCompleted))

            case .list, .thread, .delegate:
                return .none
            }
        }
    }
}
