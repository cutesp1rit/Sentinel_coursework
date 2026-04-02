import ComposableArchitecture
import Foundation

@Reducer
struct AuthReducer: Reducer {
    var body: some Reducer<AuthState, AuthAction> {
        Reduce { state, action in
            switch action {
            case let .emailChanged(email):
                state.email = email
                state.errorMessage = nil
                state.statusMessage = nil
                return .none

            case .logoutCompleted:
                state.email = ""
                state.errorMessage = nil
                state.isSubmitting = false
                state.password = ""
                state.session = nil
                state.statusMessage = L10n.Profile.loggedOutStatus
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
                state.errorMessage = nil
                state.mode = mode
                state.statusMessage = nil
                return .none

            case let .passwordChanged(password):
                state.errorMessage = nil
                state.password = password
                state.statusMessage = nil
                return .none

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
                    @Dependency(\.sessionStorageClient) var sessionStorageClient
                    do {
                        let session = try await sessionStorageClient.load()
                        await send(.restoredSession(session))
                    } catch {
                        await send(.restoreFailed(errorMessage(for: error)))
                    }
                }

            case let .restoredSession(session):
                state.email = session?.email ?? ""
                state.isRestoring = false
                state.password = ""
                state.session = session
                return .none

            case let .submitFailed(message):
                state.errorMessage = message
                state.isSubmitting = false
                return .none

            case let .submitSucceeded(session):
                state.email = session.email
                state.errorMessage = nil
                state.isSubmitting = false
                state.password = ""
                state.session = session
                state.statusMessage = L10n.Profile.signedInStatus
                return .none

            case .submitTapped:
                let email = state.email.trimmingCharacters(in: .whitespacesAndNewlines)
                let password = state.password

                if let validationError = validate(email: email, password: password) {
                    state.errorMessage = validationError
                    return .none
                }

                let mode = state.mode
                state.errorMessage = nil
                state.isSubmitting = true
                state.statusMessage = nil

                return .run { send in
                    @Dependency(\.authClient) var authClient
                    @Dependency(\.sessionStorageClient) var sessionStorageClient
                    do {
                        let session: Session

                        switch mode {
                        case .login:
                            session = try await authClient.login(email, password)

                        case .register:
                            _ = try await authClient.register(email, password)
                            session = try await authClient.login(email, password)
                        }

                        let authenticatedSession = await MainActor.run {
                            AuthenticatedSession(
                                session: session,
                                email: email
                            )
                        }
                        try await sessionStorageClient.save(authenticatedSession)
                        await send(.submitSucceeded(authenticatedSession))
                    } catch {
                        await send(.submitFailed(errorMessage(for: error)))
                    }
                }
            }
        }
    }
}

private func validate(email: String, password: String) -> String? {
    if email.isEmpty {
        return L10n.Profile.emailRequired
    }

    if !email.contains("@") {
        return L10n.Profile.emailInvalid
    }

    if password.isEmpty {
        return L10n.Profile.passwordRequired
    }

    return nil
}

private func errorMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
        return apiError.message
    }

    return error.localizedDescription
}
