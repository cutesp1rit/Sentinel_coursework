import ComposableArchitecture
import CoreGraphics

@Reducer
struct AppFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var auth = AuthState()
        var home = HomeState()
        var chatSheet = ChatSheetState.initial
        var profile = ProfileFeature.State()
        var isAuthFlowPresented = false
        var isChatSheetPresented = false
        var isProfileSheetPresented = false

        func chatSheetInsetHeight(containerHeight: CGFloat) -> CGFloat {
            guard isChatSheetPresented else { return 0 }

            switch chatSheet.detent {
            case .collapsed:
                return AppGrid.value(24)
            case .medium:
                return max(containerHeight * 0.56, 420)
            case .large:
                return containerHeight * 0.82
            }
        }
    }

    @CasePathable
    enum Action: Equatable {
        case chatSheetDismissed
        case auth(AuthAction)
        case authFlowDismissed
        case authFlowPresentationChanged(Bool)
        case chatSheetPresentationChanged(Bool)
        case home(HomeAction)
        case profile(ProfileFeature.Action)
        case profileSheetDismissed
        case profileSheetPresentationChanged(Bool)
        case task
        case chatSheet(ChatSheetAction)
    }

    struct Coordinator: Reducer {
        func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case .task:
                return .send(.auth(.restoreRequested))

            case .auth:
                let accessToken = state.auth.session?.accessToken
                let homeEffect: Effect<Action> = .send(.home(.sessionChanged(state.auth.session)))
                let profileEffect: Effect<Action> = .send(.profile(.sessionChanged(state.auth.session)))
                let chatEffect: Effect<Action> = state.chatSheet.thread.accessToken == accessToken
                    ? .none
                    : .send(.chatSheet(.accessTokenChanged(accessToken)))

                switch action {
                case .auth(.restoredSession(nil)):
                    state.isAuthFlowPresented = false
                    state.isProfileSheetPresented = false
                    state.isChatSheetPresented = false

                case .auth(.restoredSession(.some)), .auth(.submitSucceeded(_)):
                    state.isAuthFlowPresented = false
                    if !state.isProfileSheetPresented {
                        state.isChatSheetPresented = true
                    }

                default:
                    break
                }

                return .merge(chatEffect, homeEffect, profileEffect)

            case .authFlowDismissed:
                state.isAuthFlowPresented = false
                return .none

            case let .authFlowPresentationChanged(isPresented):
                state.isAuthFlowPresented = isPresented
                return .none

            case .home(.chatTapped):
                guard state.auth.session != nil else { return .none }
                if !state.isProfileSheetPresented && !state.isAuthFlowPresented {
                    state.isChatSheetPresented = true
                }
                return .none

            case .home(.profileTapped):
                guard !state.isProfileSheetPresented && !state.isAuthFlowPresented else {
                    return .none
                }
                guard state.auth.session != nil else {
                    state.auth.flow = .auth
                    state.auth.mode = .login
                    state.auth.registerStep = .email
                    state.isAuthFlowPresented = true
                    return .none
                }
                state.isChatSheetPresented = false
                state.isProfileSheetPresented = true
                return .none

            case .home(.signInTapped):
                state.auth.flow = .auth
                state.auth.mode = .login
                state.auth.registerStep = .email
                state.isAuthFlowPresented = true
                return .none

            case .home(.createAccountTapped):
                state.auth.flow = .auth
                state.auth.mode = .register
                state.auth.registerStep = .email
                state.isAuthFlowPresented = true
                return .none

            case .chatSheetDismissed:
                state.isChatSheetPresented = false
                return .none

            case let .chatSheetPresentationChanged(isPresented):
                state.isChatSheetPresented = isPresented && state.auth.session != nil
                return .none

            case .profileSheetDismissed:
                state.isProfileSheetPresented = false
                if state.auth.session != nil {
                    state.isChatSheetPresented = true
                }
                return .none

            case let .profileSheetPresentationChanged(isPresented):
                state.isProfileSheetPresented = isPresented
                return .none

            case .profile(.delegate(.sessionEnded)):
                state.isProfileSheetPresented = false
                state.isChatSheetPresented = false
                return .send(.auth(.restoredSession(nil)))

            case .chatSheet(.delegate(.suggestionApplyCompleted)):
                return .send(.home(.onAppear))

            case .chatSheet, .home, .profile:
                return .none
            }
        }
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

            Scope(state: \.profile, action: \.profile) {
                ProfileFeature()
            }

            Coordinator()
        }
    }
}
