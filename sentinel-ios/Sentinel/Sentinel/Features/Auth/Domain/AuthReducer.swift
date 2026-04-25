import ComposableArchitecture
import Foundation

@Reducer
struct AuthReducer: Reducer {
    var body: some Reducer<AuthState, AuthAction> {
        CombineReducers {
            Scope(state: \.settings, action: \.settings) {
                SettingsReducer()
            }

            Reduce { state, action in
                switch action {
                case let .confirmPasswordChanged(password):
                    state.confirmPassword = password
                    state.errorMessage = nil
                    state.statusMessage = nil
                    return .none

                case .deleteAccountCompleted:
                    state = clearedState()
                    return .none

                case let .deleteAccountFailed(message):
                    state.errorMessage = message
                    state.isDeletingAccount = false
                    return .none

                case let .deleteAccountPasswordChanged(password):
                    state.deleteAccountPassword = password
                    state.errorMessage = nil
                    return .none

                case .deleteAccountTapped:
                    guard let accessToken = state.session?.accessToken else {
                        return .none
                    }

                    let password = state.deleteAccountPassword
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !password.isEmpty else {
                        state.errorMessage = L10n.Profile.deleteAccountPasswordRequired
                        return .none
                    }

                    state.errorMessage = nil
                    state.isDeletingAccount = true
                    state.statusMessage = nil
                    return .run { send in
                        @Dependency(\.authClient) var authClient
                        @Dependency(\.sessionStorageClient) var sessionStorageClient

                        do {
                            try await authClient.deleteAccount(password, accessToken)
                            try sessionStorageClient.clear()
                            await send(.deleteAccountCompleted)
                        } catch {
                            await send(.deleteAccountFailed(errorMessage(for: error)))
                        }
                    }

                case let .emailChanged(email):
                    state.email = email
                    state.errorMessage = nil
                    state.statusMessage = nil
                    return .none

                case let .forgotPasswordCompleted(message):
                    state.errorMessage = nil
                    state.isSubmitting = false
                    state.statusMessage = message
                    return .none

                case .forgotPasswordTapped:
                    state.flow = .forgotPassword
                    state.errorMessage = nil
                    state.statusMessage = nil
                    state.password = ""
                    state.confirmPassword = ""
                    state.resetToken = ""
                    return .none

                case let .flowChanged(flow):
                    state.flow = flow
                    state.errorMessage = nil
                    state.statusMessage = nil
                    if flow == .auth {
                        state.registerStep = .email
                        state.password = ""
                        state.confirmPassword = ""
                        state.resetToken = ""
                        state.verificationToken = ""
                    }
                    return .none

                case .logoutCompleted:
                    state = clearedState()
                    return .none

                case let .logoutFailed(message):
                    state.errorMessage = message
                    state.isSubmitting = false
                    return .none

                case .logoutTapped:
                    state.errorMessage = nil
                    state.isSubmitting = true
                    state.statusMessage = nil
                    return .run { send in
                        @Dependency(\.sessionStorageClient) var sessionStorageClient
                        do {
                            try sessionStorageClient.clear()
                            await send(.logoutCompleted)
                        } catch {
                            await send(.logoutFailed(errorMessage(for: error)))
                        }
                    }

                case let .modeChanged(mode):
                    state.mode = mode
                    state.flow = .auth
                    state.registerStep = .email
                    state.password = ""
                    state.confirmPassword = ""
                    state.resetToken = ""
                    state.verificationToken = ""
                    state.errorMessage = nil
                    state.statusMessage = nil
                    state.verificationRequiredEmail = nil
                    return .none

                case let .passwordChanged(password):
                    state.password = password
                    state.errorMessage = nil
                    state.statusMessage = nil
                    return .none

                case let .registerStepChanged(step):
                    state.registerStep = step
                    state.errorMessage = nil
                    state.statusMessage = nil
                    return .none

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

                case let .resetTokenChanged(token):
                    state.resetToken = token
                    state.errorMessage = nil
                    state.statusMessage = nil
                    return .none

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

                case let .restoreFailed(message):
                    state.errorMessage = message
                    state.isRestoring = false
                    return .none

                case .restoreRequested:
                    guard !state.hasAttemptedRestore else {
                        return .none
                    }

                    state.hasAttemptedRestore = true
                    state.errorMessage = nil
                    state.isRestoring = true
                    return .run { send in
                        @Dependency(\.authClient) var authClient
                        @Dependency(\.sessionStorageClient) var sessionStorageClient
                        do {
                            let session = try await sessionStorageClient.load()
                            guard let session else {
                                await send(.restoredSession(nil))
                                return
                            }
                            let user = try await authClient.getMe(session.accessToken)
                            let validatedSession = AuthenticatedSession(session: session.session, email: user.email)
                            try await sessionStorageClient.save(validatedSession)
                            await send(.restoredSession(validatedSession))
                        } catch {
                            if let apiError = error as? APIError,
                               apiError.code == "UNAUTHORIZED" || apiError.code == "HTTP_401" {
                                try? sessionStorageClient.clear()
                                await send(.restoredSession(nil))
                            } else {
                                await send(.restoreFailed(errorMessage(for: error)))
                            }
                        }
                    }

                case let .restoredSession(session):
                    state.email = session?.email ?? ""
                    state.isRestoring = false
                    state.flow = .auth
                    state.mode = .login
                    state.registerStep = .email
                    state.password = ""
                    state.confirmPassword = ""
                    state.resetToken = ""
                    state.verificationToken = ""
                    state.deleteAccountPassword = ""
                    state.isDeletingAccount = false
                    state.session = session
                    state.settings.accessToken = session?.accessToken
                    state.settings.userEmail = session?.email
                    return .none

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

                case .settings:
                    return .none

                case let .submitFailed(message):
                    state.errorMessage = message
                    state.isSubmitting = false
                    state.isDeletingAccount = false
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
                    state.isDeletingAccount = false
                    state.password = ""
                    state.confirmPassword = ""
                    state.resetToken = ""
                    state.verificationToken = ""
                    state.deleteAccountPassword = ""
                    state.session = session
                    state.settings.accessToken = session.accessToken
                    state.settings.userEmail = session.email
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
                        let confirmPassword = state.confirmPassword
                        _ = confirmPassword
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

                case let .verificationRequired(email, message):
                    state.errorMessage = nil
                    state.isSubmitting = false
                    state.flow = .verificationPending
                    state.verificationRequiredEmail = email
                    state.statusMessage = message
                    return .none

                case let .verificationTokenChanged(token):
                    state.verificationToken = token
                    state.errorMessage = nil
                    state.statusMessage = nil
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
                }
            }
        }
    }
}

private extension AuthReducer {
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

private func clearedState() -> AuthState {
    var state = AuthState()
    return state
}

private func validateEmail(_ email: String) -> String? {
    if email.isEmpty {
        return L10n.Profile.emailRequired
    }

    if !email.contains("@") {
        return L10n.Profile.emailInvalid
    }

    return nil
}

private func validateLogin(email: String, password: String) -> String? {
    if let emailError = validateEmail(email) {
        return emailError
    }

    if password.isEmpty {
        return L10n.Profile.passwordRequired
    }

    return nil
}

private func validateRegistration(email: String, password: String, confirmPassword: String) -> String? {
    if let loginValidation = validateLogin(email: email, password: password) {
        return loginValidation == L10n.Profile.passwordRequired
            ? L10n.Profile.passwordTooShort
            : loginValidation
    }

    if password.count < 8 {
        return L10n.Profile.passwordTooShort
    }

    if confirmPassword.isEmpty {
        return L10n.Profile.confirmPasswordRequired
    }

    if password != confirmPassword {
        return L10n.Profile.passwordsDoNotMatch
    }

    return nil
}

private func validateResetPassword(token: String, password: String, confirmPassword: String) -> String? {
    if token.isEmpty {
        return L10n.Profile.resetTokenRequired
    }

    if password.count < 8 {
        return L10n.Profile.passwordTooShort
    }

    if confirmPassword.isEmpty {
        return L10n.Profile.confirmPasswordRequired
    }

    if password != confirmPassword {
        return L10n.Profile.passwordsDoNotMatch
    }

    return nil
}

nonisolated private func isVerificationRequiredError(_ error: APIError) -> Bool {
    (error.code == "FORBIDDEN" || error.code == "HTTP_403")
        && error.message.localizedCaseInsensitiveContains("verify")
}

nonisolated private func errorMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
        return apiError.message
    }

    return error.localizedDescription
}
