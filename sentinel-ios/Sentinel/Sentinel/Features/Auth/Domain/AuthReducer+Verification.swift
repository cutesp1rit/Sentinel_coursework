import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

extension AuthReducer {
    func handleVerificationActions(_ action: AuthAction, state: inout AuthState) -> Effect<AuthAction>? {
        switch action {
        case let .resendVerificationCompleted(message):
            state.errorMessage = nil
            state.isResendingVerification = false
            state.statusMessage = message
            return .none

        case let .resendVerificationFailed(message):
            state.errorMessage = message
            state.isResendingVerification = false
            return .none

        case .resendVerificationTapped:
            let email = (state.verificationRequiredEmail ?? state.email)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty else {
                state.errorMessage = L10n.Profile.emailRequired
                return .none
            }

            state.errorMessage = nil
            state.isResendingVerification = true
            state.statusMessage = nil
            return .run { send in
                @Dependency(\.authClient) var authClient
                do {
                    try await authClient.resendVerification(email)
                    await send(.resendVerificationCompleted(L10n.Profile.verificationEmailResent))
                } catch {
                    await send(.resendVerificationFailed(errorMessage(for: error)))
                }
            }

        case .retryVerificationLoginTapped:
            let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = state.password
            if let validationError = validateLogin(email: email, password: password) {
                state.errorMessage = validationError
                return .none
            }

            state.errorMessage = nil
            state.isSubmitting = true
            state.statusMessage = nil
            return loginEffect(email: email, password: password)

        case let .verificationRequired(email, message):
            state.errorMessage = nil
            state.isSubmitting = false
            state.flow = .verificationPending
            state.verificationRequiredEmail = email
            state.statusMessage = message
            return .none

        case let .verifyEmailCompleted(message):
            state.errorMessage = nil
            state.flow = .auth
            state.mode = .login
            state.registerStep = .email
            state.isSubmitting = false
            state.verificationToken = ""
            state.statusMessage = message
            return .none

        case .verifyEmailTapped:
            let token = state.verificationToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                state.errorMessage = L10n.Profile.verificationTokenRequired
                return .none
            }

            state.errorMessage = nil
            state.isSubmitting = true
            state.statusMessage = nil
            let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = state.password
            return .run { send in
                @Dependency(\.authClient) var authClient
                @Dependency(\.sessionStorageClient) var sessionStorageClient
                do {
                    try await authClient.verifyEmail(token)

                    if !email.isEmpty && !password.isEmpty {
                        let session = try await authClient.login(email, password)
                        let user = try await authClient.getMe(session.accessToken)
                        let authenticatedSession = AuthenticatedSession(
                            session: session,
                            email: user.email
                        )
                        try await sessionStorageClient.save(authenticatedSession)
                        await send(.submitSucceeded(authenticatedSession))
                    } else {
                        await send(.verifyEmailCompleted(L10n.Profile.emailVerifiedStatus))
                    }
                } catch {
                    await send(.submitFailed(errorMessage(for: error)))
                }
            }

        default:
            return nil
        }
    }
}
