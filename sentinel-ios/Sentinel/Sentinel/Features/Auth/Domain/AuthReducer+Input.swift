import ComposableArchitecture
import SentinelCore
import Foundation

extension AuthReducer {
    func handleInputActions(_ action: AuthAction, state: inout AuthState) -> Effect<AuthAction>? {
        switch action {
        case let .confirmPasswordChanged(password):
            state.confirmPassword = password
            resetMessages(state: &state)
            return .none

        case let .emailChanged(email):
            state.email = email
            resetMessages(state: &state)
            return .none

        case .forgotPasswordTapped:
            state.flow = .forgotPassword
            resetMessages(state: &state)
            state.password = ""
            state.confirmPassword = ""
            state.resetToken = ""
            return .none

        case let .flowChanged(flow):
            state.flow = flow
            resetMessages(state: &state)
            if flow == .auth {
                resetAuthFlowState(state: &state)
            }
            return .none

        case let .modeChanged(mode):
            state.mode = mode
            state.flow = .auth
            resetAuthFlowState(state: &state)
            resetMessages(state: &state)
            state.verificationRequiredEmail = nil
            return .none

        case let .passwordChanged(password):
            state.password = password
            resetMessages(state: &state)
            return .none

        case let .registerStepChanged(step):
            state.registerStep = step
            resetMessages(state: &state)
            return .none

        case let .resetTokenChanged(token):
            state.resetToken = token
            resetMessages(state: &state)
            return .none

        case let .verificationTokenChanged(token):
            state.verificationToken = token
            resetMessages(state: &state)
            return .none

        default:
            return nil
        }
    }
}
