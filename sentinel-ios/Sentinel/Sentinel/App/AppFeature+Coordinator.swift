import ComposableArchitecture
import SentinelCore

extension AppFeature {
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

                state.rebalance.accessToken = accessToken ?? ""

                switch action {
                case .auth(.restoredSession(nil)):
                    state.isAuthFlowPresented = false
                    state.isProfileSheetPresented = false
                    state.isChatSheetPresented = false
                    state.isRebalanceSheetPresented = false

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
                state.wasChatSheetPresentedBeforeProfile = state.isChatSheetPresented
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

            case .home(.rebalanceTapped):
                guard state.auth.session != nil else { return .none }
                state.wasChatSheetPresentedBeforeRebalance = state.isChatSheetPresented
                state.isChatSheetPresented = false
                state.isProfileSheetPresented = false
                let accessToken = state.auth.session?.accessToken ?? ""
                if state.rebalance.accessToken != accessToken {
                    state.rebalance = RebalanceFeature.State(accessToken: accessToken)
                } else {
                    state.rebalance.accessToken = accessToken
                }
                state.isRebalanceSheetPresented = true
                return .none

            case .chatSheetDismissed:
                state.isChatSheetPresented = false
                return .none

            case let .chatSheetPresentationChanged(isPresented):
                state.isChatSheetPresented = isPresented && state.auth.session != nil
                return .none

            case .profileSheetDismissed:
                state.isProfileSheetPresented = false
                state.isChatSheetPresented = state.auth.session != nil && state.wasChatSheetPresentedBeforeProfile
                state.wasChatSheetPresentedBeforeProfile = false
                return .none

            case let .profileSheetPresentationChanged(isPresented):
                state.isProfileSheetPresented = isPresented
                return .none

            case .rebalance(.delegate(.applied)):
                state.isRebalanceSheetPresented = false
                state.isChatSheetPresented = false
                state.wasChatSheetPresentedBeforeRebalance = false
                return .send(.home(.onAppear))

            case .rebalance(.delegate(.close)):
                state.isRebalanceSheetPresented = false
                state.isChatSheetPresented = state.auth.session != nil && state.wasChatSheetPresentedBeforeRebalance
                state.wasChatSheetPresentedBeforeRebalance = false
                return .none

            case .rebalanceSheetDismissed:
                state.isRebalanceSheetPresented = false
                state.isChatSheetPresented = state.auth.session != nil && state.wasChatSheetPresentedBeforeRebalance
                state.wasChatSheetPresentedBeforeRebalance = false
                return .none

            case let .rebalanceSheetPresentationChanged(isPresented):
                state.isRebalanceSheetPresented = isPresented
                return .none

            case .profile(.delegate(.sessionEnded)):
                state.isProfileSheetPresented = false
                state.isChatSheetPresented = false
                state.isRebalanceSheetPresented = false
                return .send(.auth(.restoredSession(nil)))

            case .chatSheet(.delegate(.suggestionApplyCompleted)):
                return .send(.home(.onAppear))

            case .chatSheet, .home, .profile, .rebalance:
                return .none
            }
        }
    }
}
