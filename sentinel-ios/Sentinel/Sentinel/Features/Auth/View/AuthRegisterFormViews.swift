import SentinelUI
import SentinelCore
import SwiftUI

struct AuthRegisterEmailFormView: View {
    let email: Binding<String>
    let isSubmitting: Bool
    let onContinue: () -> Void
    let onSwitchToLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthFormField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: email)
                    .sentinelEmailField()
            }

            PrimaryButton(L10n.Profile.continueButton, isEnabled: !isSubmitting) {
                onContinue()
            }

            SecondaryTextAction(
                L10n.Profile.loginInlineButton,
                prompt: L10n.Profile.alreadyHaveAccountPrompt
            ) {
                onSwitchToLogin()
            }
        }
    }
}

struct AuthRegisterPasswordFormView: View {
    let confirmPassword: Binding<String>
    let isSubmitting: Bool
    let password: Binding<String>
    let onBackToEmail: () -> Void
    let onRegister: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthFormField(title: L10n.Profile.passwordPlaceholder) {
                SecureField(L10n.Profile.passwordPlaceholder, text: password)
                    .textContentType(.newPassword)
            }

            AuthFormField(title: L10n.Profile.confirmPasswordPlaceholder) {
                SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPassword)
                    .textContentType(.newPassword)
            }

            PrimaryButton(L10n.Profile.registerButton, isEnabled: !isSubmitting) {
                onRegister()
            }

            Button(L10n.Profile.backToEmailButton) {
                onBackToEmail()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
        }
    }
}
