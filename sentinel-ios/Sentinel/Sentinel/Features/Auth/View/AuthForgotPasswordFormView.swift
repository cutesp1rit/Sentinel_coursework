import SentinelUI
import SentinelCore
import SwiftUI

struct AuthForgotPasswordFormView: View {
    let confirmPassword: Binding<String>
    let email: Binding<String>
    let isSubmitting: Bool
    let onBackToLogin: () -> Void
    let onResetPassword: () -> Void
    let onSendResetEmail: () -> Void
    let password: Binding<String>
    let resetToken: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthFormField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: email)
                    .sentinelEmailField()
            }

            PrimaryButton(L10n.Profile.sendResetLinkButton, isEnabled: !isSubmitting) {
                onSendResetEmail()
            }

            Text(L10n.Profile.manualResetHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            AuthFormField(title: L10n.Profile.resetTokenPlaceholder) {
                TextField(L10n.Profile.resetTokenPlaceholder, text: resetToken)
                    .sentinelTokenField()
            }

            AuthFormField(title: L10n.Profile.newPasswordPlaceholder) {
                SecureField(L10n.Profile.newPasswordPlaceholder, text: password)
                    .textContentType(.newPassword)
            }

            AuthFormField(title: L10n.Profile.confirmPasswordPlaceholder) {
                SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPassword)
                    .textContentType(.newPassword)
            }

            PrimaryButton(L10n.Profile.resetPasswordButton, isEnabled: !isSubmitting) {
                onResetPassword()
            }

            SecondaryTextAction(L10n.Profile.backToSignInButton) {
                onBackToLogin()
            }
        }
    }
}
