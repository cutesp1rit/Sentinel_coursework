import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

extension AuthReducer {
    func handleSessionActions(_ action: AuthAction, state: inout AuthState) -> Effect<AuthAction>? {
        switch action {
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
            state.session = session
            return .none

        default:
            return nil
        }
    }
}
