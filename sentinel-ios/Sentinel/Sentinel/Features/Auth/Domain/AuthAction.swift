import Foundation

enum AuthAction: Equatable {
    case emailChanged(String)
    case logoutCompleted
    case logoutFailed(String)
    case logoutTapped
    case modeChanged(AuthState.Mode)
    case passwordChanged(String)
    case restoreFailed(String)
    case restoreRequested
    case restoredSession(AuthenticatedSession?)
    case submitFailed(String)
    case submitSucceeded(AuthenticatedSession)
    case submitTapped
}
