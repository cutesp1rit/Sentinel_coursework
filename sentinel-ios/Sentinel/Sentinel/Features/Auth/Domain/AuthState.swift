import ComposableArchitecture
import SentinelCore
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
    var errorMessage: String?
    var hasAttemptedRestore = false
    var isRestoring = false
    var isResendingVerification = false
    var isSubmitting = false
    var session: AuthenticatedSession?
    var statusMessage: String?
    var verificationRequiredEmail: String?

    var isAuthenticated: Bool {
        session != nil
    }

    var screenTitle: String {
        switch (flow, mode, registerStep) {
        case (.auth, .login, _):
            return L10n.Profile.loginHeroTitle
        case (.auth, .register, .email):
            return L10n.Profile.registerEmailStepTitle
        case (.auth, .register, .credentials):
            return L10n.Profile.registerPasswordStepTitle
        case (.verificationPending, _, _):
            return L10n.Profile.verifyHeroTitle
        case (.forgotPassword, _, _):
            return L10n.Profile.forgotPasswordHeroTitle
        }
    }

    var screenSubtitle: String {
        switch (flow, mode, registerStep) {
        case (.auth, .login, _):
            return L10n.Profile.loginBody
        case (.auth, .register, .email):
            return L10n.Profile.registerEmailStepBody
        case (.auth, .register, .credentials):
            return L10n.Profile.registerPasswordStepBody
        case (.verificationPending, _, _):
            return L10n.Profile.verifyHeroBody
        case (.forgotPassword, _, _):
            return L10n.Profile.forgotPasswordBody
        }
    }

    var progressLabel: String? {
        switch (flow, mode, registerStep) {
        case (.auth, .register, .email):
            return L10n.Profile.stepProgress(1, 3)
        case (.auth, .register, .credentials):
            return L10n.Profile.stepProgress(2, 3)
        case (.verificationPending, _, _):
            return L10n.Profile.stepProgress(3, 3)
        default:
            return nil
        }
    }
}
