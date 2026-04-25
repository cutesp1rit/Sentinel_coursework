import ComposableArchitecture
import Foundation

@CasePathable
enum AuthAction: Equatable {
    case confirmPasswordChanged(String)
    case deleteAccountCompleted
    case deleteAccountFailed(String)
    case deleteAccountPasswordChanged(String)
    case deleteAccountTapped
    case emailChanged(String)
    case forgotPasswordCompleted(String)
    case forgotPasswordTapped
    case flowChanged(AuthState.Flow)
    case logoutCompleted
    case logoutFailed(String)
    case logoutTapped
    case modeChanged(AuthState.Mode)
    case passwordChanged(String)
    case registerStepChanged(AuthState.RegisterStep)
    case resendVerificationCompleted(String)
    case resendVerificationFailed(String)
    case resendVerificationTapped
    case resetPasswordCompleted(String)
    case resetPasswordTapped
    case resetTokenChanged(String)
    case retryVerificationLoginTapped
    case restoreFailed(String)
    case restoreRequested
    case restoredSession(AuthenticatedSession?)
    case sendPasswordResetEmailTapped
    case settings(SettingsAction)
    case submitFailed(String)
    case submitRegistrationCompleted(String)
    case submitSucceeded(AuthenticatedSession)
    case submitTapped
    case verificationTokenChanged(String)
    case verifyEmailCompleted(String)
    case verifyEmailTapped
    case verificationRequired(String, message: String)
}
