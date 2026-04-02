import ComposableArchitecture
import Foundation

@ObservableState
struct AuthState: Equatable {
    enum Mode: String, CaseIterable, Equatable, Identifiable {
        case login
        case register

        var id: Self { self }
    }

    var mode: Mode = .login
    var email = ""
    var password = ""
    var errorMessage: String?
    var hasAttemptedRestore = false
    var isRestoring = false
    var isSubmitting = false
    var session: AuthenticatedSession?
    var statusMessage: String?

    var isAuthenticated: Bool {
        session != nil
    }
}
