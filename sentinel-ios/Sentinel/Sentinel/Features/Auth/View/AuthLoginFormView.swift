import SentinelUI
import SentinelCore
import SwiftUI

struct AuthLoginFormView: View {
    let email: Binding<String>
    let password: Binding<String>
    let isSubmitting: Bool
    let onForgotPassword: () -> Void
    let onLogin: () -> Void
    let onSwitchToRegister: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            AuthFormField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: email)
                    .sentinelEmailField()
            }

            AuthFormField(title: L10n.Profile.passwordPlaceholder) {
                SecureField(L10n.Profile.passwordPlaceholder, text: password)
                    .textContentType(.password)
            }

            PrimaryButton(L10n.Profile.loginButton, isEnabled: !isSubmitting) {
                onLogin()
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                SecondaryTextAction(
                    L10n.Profile.registerInlineButton,
                    prompt: L10n.Profile.noAccountPrompt
                ) {
                    onSwitchToRegister()
                }

                SecondaryTextAction(L10n.Profile.forgotPasswordButton) {
                    onForgotPassword()
                }
            }
        }
    }
}
