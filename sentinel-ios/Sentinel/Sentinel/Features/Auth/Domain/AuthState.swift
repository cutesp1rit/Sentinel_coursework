import ComposableArchitecture
import Foundation

@ObservableState
struct AuthState: Equatable {
    enum Flow: Equatable {
        case auth
        case forgotPassword
        case verificationPending
    }

    enum Mode: String, CaseIterable, Equatable, Identifiable {
        case login
        case register

        var id: Self { self }
    }

    enum RegisterStep: Equatable {
        case email
        case credentials
    }

    var flow: Flow = .auth
    var mode: Mode = .login
    var registerStep: RegisterStep = .email
    var email = ""
    var password = ""
    var confirmPassword = ""
    var resetToken = ""
    var verificationToken = ""
    var deleteAccountPassword = ""
    var errorMessage: String?
    var hasAttemptedRestore = false
    var isDeletingAccount = false
    var isRestoring = false
    var isResendingVerification = false
    var isSubmitting = false
    var session: AuthenticatedSession?
    var settings = SettingsState()
    var statusMessage: String?
    var verificationRequiredEmail: String?

    var isAuthenticated: Bool {
        session != nil
    }
}
