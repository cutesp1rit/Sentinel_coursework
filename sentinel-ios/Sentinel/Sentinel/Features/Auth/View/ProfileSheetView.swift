import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<AuthReducer>

    @State private var isDeleteAccountExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppPlatformColor.systemGroupedBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.large) {
                        statusCard

                        if store.isAuthenticated {
                            signedInActions
                        } else {
                            authForm
                        }
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.xLarge)
                }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Profile.closeButton, action: onClose)
                }
            }
        }
        .task {
            store.send(.settings(.onAppear))
        }
    }

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

    private var deleteAccountPasswordBinding: Binding<String> {
        Binding(
            get: { store.deleteAccountPassword },
            set: { store.send(.deleteAccountPasswordChanged($0)) }
        )
    }

    private var modeBinding: Binding<AuthState.Mode> {
        Binding(
            get: { store.mode },
            set: { store.send(.modeChanged($0)) }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.notificationsEnabled },
            set: { store.send(.settings(.notificationsToggleChanged($0))) }
        )
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if store.isRestoring {
                HStack(spacing: AppSpacing.medium) {
                    ProgressView()
                    Text(L10n.Profile.restoringStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let session = store.session {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(displayName(for: session.email))
                            .font(.title3.weight(.semibold))

                        Text(session.email)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(L10n.Profile.signedOutTitle)
                    .font(.headline)

                Text(L10n.Profile.signedOutBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = store.statusMessage {
                Text(statusMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    @ViewBuilder
    private var authForm: some View {
        switch store.flow {
        case .auth:
            authCredentialsForm
        case .forgotPassword:
            forgotPasswordForm
        case .verificationPending:
            verificationPendingForm
        }
    }

    private var authCredentialsForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Picker(
                L10n.Profile.modePickerLabel,
                selection: modeBinding
            ) {
                Text(L10n.Profile.loginMode).tag(AuthState.Mode.login)
                Text(L10n.Profile.registerMode).tag(AuthState.Mode.register)
            }
            .pickerStyle(.segmented)

            if store.mode == .login {
                loginForm
            } else {
                registerForm
            }

            Text(L10n.Profile.authHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var loginForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            formField(
                title: L10n.Profile.emailPlaceholder
            ) {
                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                    .appNeverAutocapitalized()
                    .appUsernameContentType()
                    .autocorrectionDisabled()
            }

            formField(
                title: L10n.Profile.passwordPlaceholder
            ) {
                SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                    .appPasswordContentType()
            }

            primaryButton(
                title: L10n.Profile.loginButton,
                isLoading: store.isSubmitting
            ) {
                store.send(.submitTapped)
            }
            .disabled(store.isSubmitting || store.isRestoring)

            Button(L10n.Profile.forgotPasswordButton) {
                store.send(.forgotPasswordTapped)
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
        }
    }

    @ViewBuilder
    private var registerForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            if store.registerStep == .email {
                Text(L10n.Profile.registerEmailStepTitle)
                    .font(.headline)

                Text(L10n.Profile.registerEmailStepBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                formField(title: L10n.Profile.emailPlaceholder) {
                    TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                        .appNeverAutocapitalized()
                        .appEmailContentType()
                        .autocorrectionDisabled()
                }

                primaryButton(title: L10n.Profile.continueButton) {
                    store.send(.submitTapped)
                }
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(L10n.Profile.registerPasswordStepTitle)
                        .font(.headline)

                    Text(store.email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                formField(title: L10n.Profile.passwordPlaceholder) {
                    SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                        .appNewPasswordContentType()
                }

                formField(title: L10n.Profile.confirmPasswordPlaceholder) {
                    SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPasswordBinding)
                        .appNewPasswordContentType()
                }

                HStack(spacing: AppSpacing.medium) {
                    secondaryButton(title: L10n.Profile.backToEmailButton) {
                        store.send(.registerStepChanged(.email))
                    }

                    primaryButton(
                        title: L10n.Profile.registerButton,
                        isLoading: store.isSubmitting
                    ) {
                        store.send(.submitTapped)
                    }
                }
            }
        }
    }

    private var verificationPendingForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Profile.verificationRequiredTitle)
                    .font(.headline)

                Text(
                    L10n.Profile.verificationPendingBody(
                        store.verificationRequiredEmail ?? store.email
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.large)
            .background(AppPlatformColor.secondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

            primaryButton(
                title: L10n.Profile.trySignInAgainButton,
                isLoading: store.isSubmitting
            ) {
                store.send(.retryVerificationLoginTapped)
            }

            secondaryButton(
                title: L10n.Profile.resendVerificationButton,
                isLoading: store.isResendingVerification
            ) {
                store.send(.resendVerificationTapped)
            }

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Profile.manualVerificationHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                formField(title: L10n.Profile.verificationTokenPlaceholder) {
                    TextField(
                        L10n.Profile.verificationTokenPlaceholder,
                        text: verificationTokenBinding
                    )
                    .appNeverAutocapitalized()
                    .autocorrectionDisabled()
                }

                primaryButton(
                    title: L10n.Profile.verifyEmailButton,
                    isLoading: store.isSubmitting
                ) {
                    store.send(.verifyEmailTapped)
                }
            }

            secondaryButton(title: L10n.Profile.backToSignInButton) {
                store.send(.flowChanged(.auth))
            }
        }
    }

    private var forgotPasswordForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Profile.forgotPasswordTitle)
                    .font(.headline)

                Text(L10n.Profile.forgotPasswordBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(AppSpacing.large)
            .background(AppPlatformColor.secondaryGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

            formField(title: L10n.Profile.emailPlaceholder) {
                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                    .appNeverAutocapitalized()
                    .appEmailContentType()
                    .autocorrectionDisabled()
            }

            primaryButton(
                title: L10n.Profile.sendResetLinkButton,
                isLoading: store.isSubmitting
            ) {
                store.send(.sendPasswordResetEmailTapped)
            }

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Profile.manualResetHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                formField(title: L10n.Profile.resetTokenPlaceholder) {
                    TextField(
                        L10n.Profile.resetTokenPlaceholder,
                        text: resetTokenBinding
                    )
                    .appNeverAutocapitalized()
                    .autocorrectionDisabled()
                }

                formField(title: L10n.Profile.newPasswordPlaceholder) {
                    SecureField(
                        L10n.Profile.newPasswordPlaceholder,
                        text: passwordBinding
                    )
                    .appNewPasswordContentType()
                }

                formField(title: L10n.Profile.confirmPasswordPlaceholder) {
                    SecureField(
                        L10n.Profile.confirmPasswordPlaceholder,
                        text: confirmPasswordBinding
                    )
                    .appNewPasswordContentType()
                }

                primaryButton(
                    title: L10n.Profile.resetPasswordButton,
                    isLoading: store.isSubmitting
                ) {
                    store.send(.resetPasswordTapped)
                }
            }

            secondaryButton(title: L10n.Profile.backToSignInButton) {
                store.send(.flowChanged(.auth))
            }
        }
    }

    private var signedInActions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            settingsSectionCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(L10n.Settings.notificationsTitle)
                        .font(.headline)

                    Toggle(L10n.Settings.notificationsEnabled, isOn: notificationsBinding)
                }
            }

            promptTemplateSection

            if let accessToken = store.settings.accessToken {
                NavigationLink {
                    AchievementsView(
                        store: Store(initialState: AchievementsState(accessToken: accessToken)) {
                            AchievementsReducer()
                        }
                    )
                } label: {
                    settingsRow(
                        title: L10n.Achievements.title,
                        systemImage: "rosette"
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                store.send(.logoutTapped)
            } label: {
                settingsRow(
                    title: L10n.Profile.logoutButton,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: .red,
                    trailing: AnyView(
                        Group {
                            if store.isSubmitting {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isSubmitting || store.isDeletingAccount)

            deleteAccountSection
        }
    }

    private var promptTemplateSection: some View {
        settingsSectionCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Settings.defaultPromptTitle)
                    .font(.headline)

                TextEditor(
                    text: Binding(
                        get: { store.settings.defaultPromptTemplate },
                        set: { store.send(.settings(.defaultPromptChanged($0))) }
                    )
                )
                .frame(minHeight: 140)
                .padding(AppSpacing.medium)
                .background(AppPlatformColor.tertiaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                primaryButton(title: L10n.Settings.savePromptButton) {
                    store.send(.settings(.savePromptTapped))
                }

                Text(L10n.Settings.defaultPromptFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let statusMessage = store.settings.statusMessage {
                    Text(statusMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var deleteAccountSection: some View {
        settingsSectionCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDeleteAccountExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text(L10n.Profile.deleteAccountButton)
                            .font(.headline)
                            .foregroundStyle(.red)

                        Spacer()

                        Image(systemName: isDeleteAccountExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isDeleteAccountExpanded {
                    Text(L10n.Profile.deleteAccountBody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SecureField(
                        L10n.Profile.deleteAccountPasswordPlaceholder,
                        text: deleteAccountPasswordBinding
                    )
                    .appPasswordContentType()
                    .padding(AppSpacing.large)
                    .background(AppPlatformColor.tertiaryGroupedBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                    HStack(spacing: AppSpacing.medium) {
                        secondaryButton(title: L10n.Profile.cancelButton) {
                            store.send(.deleteAccountPasswordChanged(""))
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDeleteAccountExpanded = false
                            }
                        }

                        primaryButton(
                            title: L10n.Profile.deleteAccountConfirmButton,
                            tint: .red,
                            isLoading: store.isDeletingAccount
                        ) {
                            store.send(.deleteAccountTapped)
                        }
                    }
                }
            }
        }
    }

    private func formField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .padding(AppSpacing.large)
                .background(AppPlatformColor.secondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
    }

    private func settingsSectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private func primaryButton(
        title: String,
        tint: Color = .accentColor,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .font(.body.weight(.semibold))
            .padding(.vertical, AppSpacing.medium)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }

    private func secondaryButton(
        title: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                }

                Text(title)
                    .frame(maxWidth: .infinity)
            }
            .font(.body.weight(.semibold))
            .padding(.vertical, AppSpacing.medium)
        }
        .buttonStyle(.bordered)
    }

    private func displayName(for email: String) -> String {
        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        return localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func settingsRow(
        title: String,
        systemImage: String,
        tint: Color = .primary,
        trailing: AnyView = AnyView(
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        )
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: AppGrid.value(8), height: AppGrid.value(8))
                .background(AppPlatformColor.tertiaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            Text(title)
                .font(.body)
                .foregroundStyle(tint)

            Spacer()

            trailing
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

private extension View {
    @ViewBuilder
    func appNeverAutocapitalized() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appEmailContentType() -> some View {
        #if os(iOS)
        self.textContentType(.emailAddress)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appUsernameContentType() -> some View {
        #if os(iOS)
        self.textContentType(.username)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appPasswordContentType() -> some View {
        #if os(iOS)
        self.textContentType(.password)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appNewPasswordContentType() -> some View {
        #if os(iOS)
        self.textContentType(.newPassword)
        #else
        self
        #endif
    }
}

#Preview("Signed Out") {
    ProfileSheetView(
        onClose: {},
        store: Store(initialState: AuthState()) {
            AuthReducer()
        }
    )
}

#Preview("Signed In") {
    ProfileSheetView(
        onClose: {},
        store: Store(
            initialState: AuthState(
                session: AuthenticatedSession(
                    session: Session(accessToken: "token", tokenType: "Bearer"),
                    email: "person@example.com"
                )
            )
        ) {
            AuthReducer()
        }
    )
}
