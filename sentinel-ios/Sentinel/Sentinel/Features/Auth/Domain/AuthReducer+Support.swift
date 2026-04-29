import Foundation
import SentinelCore

extension AuthReducer {
    func resetMessages(state: inout AuthState) {
        state.errorMessage = nil
        state.statusMessage = nil
    }

    func resetAuthFlowState(state: inout AuthState) {
        state.registerStep = .email
        state.password = ""
        state.confirmPassword = ""
        state.resetToken = ""
        state.verificationToken = ""
    }
}

func validateEmail(_ email: String) -> String? {
    if email.isEmpty {
        return L10n.Profile.emailRequired
    }

    if !email.contains("@") {
        return L10n.Profile.emailInvalid
    }

    return nil
}

func validateLogin(email: String, password: String) -> String? {
    if let emailError = validateEmail(email) {
        return emailError
    }

    if password.isEmpty {
        return L10n.Profile.passwordRequired
    }

    return nil
}

func validateRegistration(email: String, password: String, confirmPassword: String) -> String? {
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

func validateResetPassword(token: String, password: String, confirmPassword: String) -> String? {
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

nonisolated func isVerificationRequiredError(_ error: APIError) -> Bool {
    (error.code == "FORBIDDEN" || error.code == "HTTP_403")
        && error.message.localizedCaseInsensitiveContains("verify")
}

nonisolated func errorMessage(for error: Error) -> String {
    if let apiError = error as? APIError {
        return apiError.message
    }

    return error.localizedDescription
}
