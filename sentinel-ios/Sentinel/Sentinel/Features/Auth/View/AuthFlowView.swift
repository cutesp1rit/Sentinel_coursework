import SentinelUI
import SentinelCore
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

    private var resetTokenBinding: Binding<String> {
        Binding(
            get: { store.resetToken },
            set: { store.send(.resetTokenChanged($0)) }
        )
    }

    private var verificationTokenBinding: Binding<String> {
        Binding(
            get: { store.verificationToken },
            set: { store.send(.verificationTokenChanged($0)) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    topBar
                    header
                    formCard
                    AuthLegalLinksView()
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
                AuthStatusBanner(message: statusMessage, tint: .secondary.opacity(0.12), foreground: .secondary)
            }

            if let errorMessage = store.errorMessage {
                AuthStatusBanner(message: errorMessage, tint: .red.opacity(0.12), foreground: .red)
            }

            switch (store.flow, store.mode, store.registerStep) {
            case (.auth, .login, _):
                AuthLoginFormView(
                    email: emailBinding,
                    password: passwordBinding,
                    isSubmitting: store.isSubmitting,
                    onForgotPassword: { store.send(.forgotPasswordTapped) },
                    onLogin: { store.send(.submitTapped) },
                    onSwitchToRegister: { store.send(.modeChanged(.register)) }
                )

            case (.auth, .register, .email):
                AuthRegisterEmailFormView(
                    email: emailBinding,
                    isSubmitting: store.isSubmitting,
                    onContinue: { store.send(.submitTapped) },
                    onSwitchToLogin: { store.send(.modeChanged(.login)) }
                )

            case (.auth, .register, .credentials):
                AuthRegisterPasswordFormView(
                    confirmPassword: confirmPasswordBinding,
                    isSubmitting: store.isSubmitting,
                    password: passwordBinding,
                    onBackToEmail: { store.send(.registerStepChanged(.email)) },
                    onRegister: { store.send(.submitTapped) }
                )

            case (.verificationPending, _, _):
                AuthVerificationFormView(
                    email: store.verificationRequiredEmail ?? store.email,
                    isResendingVerification: store.isResendingVerification,
                    isSubmitting: store.isSubmitting,
                    onBackToLogin: { store.send(.modeChanged(.login)) },
                    onResend: { store.send(.resendVerificationTapped) },
                    onRetryLogin: { store.send(.retryVerificationLoginTapped) },
                    onVerify: { store.send(.verifyEmailTapped) },
                    verificationToken: verificationTokenBinding
                )

            case (.forgotPassword, _, _):
                AuthForgotPasswordFormView(
                    confirmPassword: confirmPasswordBinding,
                    email: emailBinding,
                    isSubmitting: store.isSubmitting,
                    onBackToLogin: { store.send(.modeChanged(.login)) },
                    onResetPassword: { store.send(.resetPasswordTapped) },
                    onSendResetEmail: { store.send(.sendPasswordResetEmailTapped) },
                    password: passwordBinding,
                    resetToken: resetTokenBinding
                )
            }
        }
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
