import ComposableArchitecture

struct AppFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var auth = AuthState()
        var home = HomeState()
        var chatSheet = ChatSheetState.initial
        var isChatSheetPresented = true
        var isProfileSheetPresented = false
        var pendingSheet: PendingSheet?
        var shouldRestoreChatSheetAfterProfile = false
    }

    enum PendingSheet: Equatable {
        case chat
        case profile
    }

    @CasePathable
    enum Action: Equatable {
        case chatSheetDismissed
        case auth(AuthAction)
        case chatSheetPresentationChanged(Bool)
        case home(HomeAction)
        case profileSheetDismissed
        case profileSheetPresentationChanged(Bool)
        case task
        case chatSheet(ChatSheetAction)
    }

    var body: some Reducer<State, Action> {
        CombineReducers {
            Scope(state: \.auth, action: \.auth) {
                AuthReducer()
            }

            Scope(state: \.home, action: \.home) {
                HomeReducer()
            }

            Scope(state: \.chatSheet, action: \.chatSheet) {
                ChatSheetReducer()
            }
        }

        Reduce { state, action in
            switch action {
            case .task:
                return .send(.auth(.restoreRequested))

            case .auth:
                let accessToken = state.auth.session?.accessToken
                guard state.chatSheet.accessToken != accessToken else {
                    return .none
                }
                return .send(.chatSheet(.accessTokenChanged(accessToken)))

            case .home(.chatTapped):
                if state.isProfileSheetPresented {
                    state.pendingSheet = .chat
                    state.shouldRestoreChatSheetAfterProfile = false
                    state.isProfileSheetPresented = false
                } else {
                    state.isChatSheetPresented = true
                }
                return .none

            case .home(.profileTapped):
                guard !state.isProfileSheetPresented else {
                    return .none
                }

                state.shouldRestoreChatSheetAfterProfile = state.isChatSheetPresented

                if state.isChatSheetPresented {
                    state.pendingSheet = .profile
                    state.isChatSheetPresented = false
                    return .none
                }

                state.isProfileSheetPresented = true
                return .none

            case .chatSheetDismissed:
                guard state.pendingSheet == .profile else {
                    return .none
                }
                state.pendingSheet = nil
                state.isProfileSheetPresented = true
                return .none

            case let .chatSheetPresentationChanged(isPresented):
                state.isChatSheetPresented = isPresented
                return .none

            case .profileSheetDismissed:
                state.isProfileSheetPresented = false

                if state.pendingSheet == .chat {
                    state.pendingSheet = nil
                    state.isChatSheetPresented = true
                    return .none
                }

                guard state.shouldRestoreChatSheetAfterProfile else {
                    return .none
                }

                state.shouldRestoreChatSheetAfterProfile = false
                state.isChatSheetPresented = true
                return .none

            case let .profileSheetPresentationChanged(isPresented):
                state.isProfileSheetPresented = isPresented
                return .none

            case .chatSheet, .home:
                return .none
            }
        }
    }
}
