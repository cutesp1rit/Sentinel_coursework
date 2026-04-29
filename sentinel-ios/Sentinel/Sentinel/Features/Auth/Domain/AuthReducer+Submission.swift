import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

extension AuthReducer {
    func handleSubmissionActions(_ action: AuthAction, state: inout AuthState) -> Effect<AuthAction>? {
        switch action {
        case let .submitFailed(message):
            state.errorMessage = message
            state.isSubmitting = false
            return .none

        case let .submitRegistrationCompleted(email):
            state.email = email
            state.flow = .verificationPending
            state.registerStep = .email
            state.errorMessage = nil
            state.isSubmitting = false
            state.confirmPassword = ""
            state.verificationRequiredEmail = email
            state.statusMessage = nil
            return .none

        case let .submitSucceeded(session):
            state.email = session.email
            state.errorMessage = nil
            state.flow = .auth
            state.mode = .login
            state.registerStep = .email
            state.isSubmitting = false
            state.password = ""
            state.confirmPassword = ""
            state.resetToken = ""
            state.verificationToken = ""
            state.session = session
            state.statusMessage = nil
            state.verificationRequiredEmail = nil
            return .none

        case .submitTapped:
            guard state.flow == .auth else {
                return .none
            }

            let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
            let password = state.password

            switch state.mode {
            case .login:
                if let validationError = validateLogin(email: email, password: password) {
                    state.errorMessage = validationError
                    return .none
                }

                state.errorMessage = nil
                state.isSubmitting = true
                state.statusMessage = nil
                return loginEffect(email: email, password: password)

            case .register:
                if state.registerStep == .email {
                    if let validationError = validateEmail(email) {
                        state.errorMessage = validationError
                        return .none
                    }
                    state.registerStep = .credentials
                    state.errorMessage = nil
                    return .none
                }

                if let validationError = validateRegistration(
                    email: email,
                    password: password,
                    confirmPassword: state.confirmPassword
                ) {
                    state.errorMessage = validationError
                    return .none
                }

                state.errorMessage = nil
                state.isSubmitting = true
                state.statusMessage = nil
                return .run { send in
                    @Dependency(\.authClient) var authClient
                    @Dependency(\.sessionStorageClient) var sessionStorageClient
                    do {
                        let user = try await authClient.register(
                            email,
                            password,
                            TimeZone.current.identifier
                        )

                        if user.isVerified {
                            let session = try await authClient.login(email, password)
                            let authenticatedSession = AuthenticatedSession(
                                session: session,
                                email: user.email
                            )
                            try await sessionStorageClient.save(authenticatedSession)
                            await send(.submitSucceeded(authenticatedSession))
                        } else {
                            await send(.submitRegistrationCompleted(email))
                        }
                    } catch {
                        await send(.submitFailed(errorMessage(for: error)))
                    }
                }
            }

        default:
            return nil
        }
    }

    func loginEffect(email: String, password: String) -> Effect<AuthAction> {
        .run { send in
            @Dependency(\.authClient) var authClient
            @Dependency(\.sessionStorageClient) var sessionStorageClient

            do {
                let session = try await authClient.login(email, password)
                let user = try await authClient.getMe(session.accessToken)
                let authenticatedSession = AuthenticatedSession(
                    session: session,
                    email: user.email
                )
                try await sessionStorageClient.save(authenticatedSession)
                await send(.submitSucceeded(authenticatedSession))
            } catch {
                if let apiError = error as? APIError,
                   isVerificationRequiredError(apiError) {
                    await send(.verificationRequired(email, message: apiError.message))
                } else {
                    await send(.submitFailed(errorMessage(for: error)))
                }
            }
        }
    }
}
