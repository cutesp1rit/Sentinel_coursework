import ComposableArchitecture
import SwiftUI

struct AuthFlowView: View {
    let onClose: () -> Void
    let store: StoreOf<AuthReducer>

    private var emailBinding: Binding<String> {
        Binding(
            get: { store.email },
            set: { store.send(.emailChanged($0)) }
        )
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { store.password },
            set: { store.send(.passwordChanged($0)) }
        )
    }

    private var confirmPasswordBinding: Binding<String> {
        Binding(
            get: { store.confirmPassword },
            set: { store.send(.confirmPasswordChanged($0)) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    topBar
                    header
                    formCard
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.xLarge)
                .padding(.bottom, AppSpacing.xLarge)
            }
            .scrollIndicators(.hidden)
            .background(AppPlatformColor.systemGroupedBackground.ignoresSafeArea())
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if let progressLabel = store.progressLabel {
                Text(progressLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(store.screenTitle)
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text(store.screenSubtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var formCard: some View {
        AuthFormCard {
            if let statusMessage = store.statusMessage {
                authBanner(statusMessage, tint: .secondary.opacity(0.12), foreground: .secondary)
            }

            if let errorMessage = store.errorMessage {
                authBanner(errorMessage, tint: .red.opacity(0.12), foreground: .red)
            }

            switch (store.flow, store.mode, store.registerStep) {
            case (.auth, .login, _):
                loginForm

            case (.auth, .register, .email):
                registerEmailForm

            case (.auth, .register, .credentials):
                registerPasswordForm

            case (.verificationPending, _, _):
                verificationForm

            case (.forgotPassword, _, _):
                forgotPasswordForm
            }
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            formField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                    .sentinelEmailField()
            }

            formField(title: L10n.Profile.passwordPlaceholder) {
                SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                    .textContentType(.password)
            }

            PrimaryButton(L10n.Profile.loginButton, isEnabled: !store.isSubmitting) {
                store.send(.submitTapped)
            }

            VStack(alignment: .leading, spacing: AppSpacing.small) {
                SecondaryTextAction(
                    L10n.Profile.registerInlineButton,
                    prompt: L10n.Profile.noAccountPrompt
                ) {
                    store.send(.modeChanged(.register))
                }

                SecondaryTextAction(L10n.Profile.forgotPasswordButton) {
                    store.send(.forgotPasswordTapped)
                }
            }
        }
    }

    private var registerEmailForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            formField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                    .sentinelEmailField()
            }

            PrimaryButton(L10n.Profile.continueButton, isEnabled: !store.isSubmitting) {
                store.send(.submitTapped)
            }

            SecondaryTextAction(
                L10n.Profile.loginInlineButton,
                prompt: L10n.Profile.alreadyHaveAccountPrompt
            ) {
                store.send(.modeChanged(.login))
            }
        }
    }

    private var registerPasswordForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            formField(title: L10n.Profile.passwordPlaceholder) {
                SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                    .textContentType(.newPassword)
            }

            formField(title: L10n.Profile.confirmPasswordPlaceholder) {
                SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPasswordBinding)
                    .textContentType(.newPassword)
            }

            PrimaryButton(L10n.Profile.registerButton, isEnabled: !store.isSubmitting) {
                store.send(.submitTapped)
            }

            Button(L10n.Profile.backToEmailButton) {
                store.send(.registerStepChanged(.email))
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
        }
    }

    private var verificationForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            EmptyStateCard(
                title: L10n.Profile.verificationRequiredTitle,
                bodyText: L10n.Profile.verificationPendingBody(store.verificationRequiredEmail ?? store.email)
            )

            PrimaryButton(L10n.Profile.trySignInAgainButton, isEnabled: !store.isSubmitting) {
                store.send(.retryVerificationLoginTapped)
            }

            Button(L10n.Profile.resendVerificationButton) {
                store.send(.resendVerificationTapped)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))

            SecondaryTextAction(L10n.Profile.backToSignInButton) {
                store.send(.modeChanged(.login))
            }
        }
    }

    private var forgotPasswordForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            formField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                    .sentinelEmailField()
            }

            PrimaryButton(L10n.Profile.sendResetLinkButton, isEnabled: !store.isSubmitting) {
                store.send(.sendPasswordResetEmailTapped)
            }

            SecondaryTextAction(L10n.Profile.backToSignInButton) {
                store.send(.modeChanged(.login))
            }
        }
    }

    private func authBanner(
        _ message: String,
        tint: Color,
        foreground: Color
    ) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func formField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(.horizontal, AppSpacing.large)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPlatformColor.secondaryGroupedBackground.opacity(0.84))
                )
        }
    }
}

private extension View {
    @ViewBuilder
    func sentinelEmailField() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.emailAddress)
            .textContentType(.username)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}

#Preview("Auth Flow") {
    AuthFlowView(
        onClose: {},
        store: Store(initialState: AuthState()) {
            AuthReducer()
        }
    )
}
