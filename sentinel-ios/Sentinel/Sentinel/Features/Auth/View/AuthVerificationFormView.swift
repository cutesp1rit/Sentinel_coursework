import SentinelUI
import SentinelCore
import SwiftUI

struct AuthVerificationFormView: View {
    let email: String
    let isResendingVerification: Bool
    let isSubmitting: Bool
    let onBackToLogin: () -> Void
    let onResend: () -> Void
    let onRetryLogin: () -> Void
    let onVerify: () -> Void
    let verificationToken: Binding<String>

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            EmptyStateCard(
                title: L10n.Profile.verificationRequiredTitle,
                bodyText: L10n.Profile.verificationPendingBody(email)
            )

            Text(L10n.Profile.manualVerificationHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            AuthFormField(title: L10n.Profile.verificationTokenPlaceholder) {
                TextField(L10n.Profile.verificationTokenPlaceholder, text: verificationToken)
                    .sentinelTokenField()
            }

            PrimaryButton(L10n.Profile.verifyEmailButton, isEnabled: !isSubmitting) {
                onVerify()
            }

            PrimaryButton(L10n.Profile.trySignInAgainButton, isEnabled: !isSubmitting) {
                onRetryLogin()
            }

            Button(L10n.Profile.resendVerificationButton) {
                onResend()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .disabled(isResendingVerification)
            .opacity(isResendingVerification ? AppOpacity.disabled : 1)

            SecondaryTextAction(L10n.Profile.backToSignInButton) {
                onBackToLogin()
            }
        }
    }
}
