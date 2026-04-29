import ComposableArchitecture
import SentinelCore
import Foundation

extension AuthReducer {
    func handlePasswordResetActions(_ action: AuthAction, state: inout AuthState) -> Effect<AuthAction>? {
        switch action {
        case let .forgotPasswordCompleted(message):
            state.errorMessage = nil
            state.isSubmitting = false
            state.statusMessage = message
            return .none

        case let .resetPasswordCompleted(message):
            state.errorMessage = nil
            state.flow = .auth
            state.mode = .login
            state.registerStep = .email
            state.isSubmitting = false
            state.password = ""
            state.confirmPassword = ""
            state.resetToken = ""
            state.statusMessage = message
            return .none

        case .resetPasswordTapped:
            let token = state.resetToken.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = state.password
            let confirmPassword = state.confirmPassword
            if let validationError = validateResetPassword(
                token: token,
                password: password,
                confirmPassword: confirmPassword
            ) {
                state.errorMessage = validationError
                return .none
            }

            state.errorMessage = nil
            state.isSubmitting = true
            state.statusMessage = nil
            return .run { send in
                @Dependency(\.authClient) var authClient
                do {
                    try await authClient.resetPassword(token, password)
                    await send(.resetPasswordCompleted(L10n.Profile.passwordResetSucceeded))
                } catch {
                    await send(.submitFailed(errorMessage(for: error)))
                }
            }

        case .sendPasswordResetEmailTapped:
            let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
            if let validationError = validateEmail(email) {
                state.errorMessage = validationError
                return .none
            }

            state.errorMessage = nil
            state.isSubmitting = true
            state.statusMessage = nil
            return .run { send in
                @Dependency(\.authClient) var authClient
                do {
                    try await authClient.forgotPassword(email)
                    await send(.forgotPasswordCompleted(L10n.Profile.passwordResetEmailSent))
                } catch {
                    await send(.submitFailed(errorMessage(for: error)))
                }
            }

        default:
            return nil
        }
    }
}
