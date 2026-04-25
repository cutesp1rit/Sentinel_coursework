import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<AuthReducer>

    @State private var isDeleteAccountExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                authBackground
                    .ignoresSafeArea()

                if store.isAuthenticated {
                    signedInContent
                } else {
                    authContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.notificationsEnabled },
            set: { store.send(.settings(.notificationsToggleChanged($0))) }
        )
    }

    private var deleteAccountPasswordBinding: Binding<String> {
        Binding(
            get: { store.deleteAccountPassword },
            set: { store.send(.deleteAccountPasswordChanged($0)) }
        )
    }

    private var authBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.97, blue: 1.0),
                Color(red: 0.96, green: 0.93, blue: 0.99),
                AppPlatformColor.systemGroupedBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }

    private var signedInContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                signedInHeader
                signedInActions
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.xLarge)
            .padding(.bottom, AppSpacing.xLarge)
        }
    }

    private var authContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                authHero

                switch store.flow {
                case .auth:
                    if store.mode == .login {
                        loginCard
                    } else {
                        registerCard
                    }
                case .forgotPassword:
                    forgotPasswordCard
                case .verificationPending:
                    verificationPendingCard
                }

                if let errorMessage = store.errorMessage {
                    statusBanner(
                        message: errorMessage,
                        tint: .red
                    )
                } else if let statusMessage = store.statusMessage {
                    statusBanner(
                        message: statusMessage,
                        tint: Color.accentColor
                    )
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.top, AppSpacing.xLarge)
            .padding(.bottom, AppSpacing.xLarge)
        }
    }

    private var authHero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Sentinel")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(heroTitle)
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)

            Text(heroBody)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loginCard: some View {
        authCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                sectionTitle(
                    title: L10n.Profile.loginTitle,
                    body: L10n.Profile.loginBody
                )

                authFieldGroup {
                    authField(
                        title: L10n.Profile.emailPlaceholder,
                        content: AnyView(
                            TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                                .appNeverAutocapitalized()
                                .appUsernameContentType()
                                .autocorrectionDisabled()
                        )
                    )

                    authField(
                        title: L10n.Profile.passwordPlaceholder,
                        content: AnyView(
                            SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                                .appPasswordContentType()
                        )
                    )
                }

                primaryButton(
                    title: L10n.Profile.loginButton,
                    isLoading: store.isSubmitting
                ) {
                    store.send(.submitTapped)
                }

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    inlineActionRow(
                        prompt: L10n.Profile.noAccountPrompt,
                        actionTitle: L10n.Profile.registerInlineButton
                    ) {
                        store.send(.modeChanged(.register))
                    }

                    inlineActionRow(
                        prompt: L10n.Profile.forgotPasswordPrompt,
                        actionTitle: L10n.Profile.forgotPasswordButton
                    ) {
                        store.send(.forgotPasswordTapped)
                    }
                }
            }
        }
    }

    private var registerCard: some View {
        authCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                stepHeader(
                    current: store.registerStep == .email ? 1 : 2,
                    total: 2,
                    title: store.registerStep == .email
                        ? L10n.Profile.registerEmailStepTitle
                        : L10n.Profile.registerPasswordStepTitle,
                    body: store.registerStep == .email
                        ? L10n.Profile.registerEmailStepBody
                        : L10n.Profile.registerPasswordStepBody
                )

                if store.registerStep == .email {
                    authFieldGroup {
                        authField(
                            title: L10n.Profile.emailPlaceholder,
                            content: AnyView(
                                TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                                    .appNeverAutocapitalized()
                                    .appEmailContentType()
                                    .autocorrectionDisabled()
                            )
                        )
                    }

                    primaryButton(title: L10n.Profile.continueButton) {
                        store.send(.submitTapped)
                    }
                } else {
                    authFieldGroup {
                        authField(
                            title: L10n.Profile.passwordPlaceholder,
                            content: AnyView(
                                SecureField(L10n.Profile.passwordPlaceholder, text: passwordBinding)
                                    .appNewPasswordContentType()
                            )
                        )

                        authField(
                            title: L10n.Profile.confirmPasswordPlaceholder,
                            content: AnyView(
                                SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPasswordBinding)
                                    .appNewPasswordContentType()
                            )
                        )
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

                inlineActionRow(
                    prompt: L10n.Profile.alreadyHaveAccountPrompt,
                    actionTitle: L10n.Profile.loginInlineButton
                ) {
                    store.send(.modeChanged(.login))
                }
            }
        }
    }

    private var forgotPasswordCard: some View {
        authCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                sectionTitle(
                    title: L10n.Profile.forgotPasswordTitle,
                    body: L10n.Profile.forgotPasswordBody
                )

                authFieldGroup {
                    authField(
                        title: L10n.Profile.emailPlaceholder,
                        content: AnyView(
                            TextField(L10n.Profile.emailPlaceholder, text: emailBinding)
                                .appNeverAutocapitalized()
                                .appEmailContentType()
                                .autocorrectionDisabled()
                        )
                    )
                }

                primaryButton(
                    title: L10n.Profile.sendResetLinkButton,
                    isLoading: store.isSubmitting
                ) {
                    store.send(.sendPasswordResetEmailTapped)
                }

                Divider()

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(L10n.Profile.manualResetHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    authFieldGroup {
                        authField(
                            title: L10n.Profile.resetTokenPlaceholder,
                            content: AnyView(
                                TextField(L10n.Profile.resetTokenPlaceholder, text: resetTokenBinding)
                                    .appNeverAutocapitalized()
                                    .autocorrectionDisabled()
                            )
                        )

                        authField(
                            title: L10n.Profile.newPasswordPlaceholder,
                            content: AnyView(
                                SecureField(L10n.Profile.newPasswordPlaceholder, text: passwordBinding)
                                    .appNewPasswordContentType()
                            )
                        )

                        authField(
                            title: L10n.Profile.confirmPasswordPlaceholder,
                            content: AnyView(
                                SecureField(L10n.Profile.confirmPasswordPlaceholder, text: confirmPasswordBinding)
                                    .appNewPasswordContentType()
                            )
                        )
                    }

                    primaryButton(
                        title: L10n.Profile.resetPasswordButton,
                        isLoading: store.isSubmitting
                    ) {
                        store.send(.resetPasswordTapped)
                    }
                }

                inlineActionRow(
                    prompt: L10n.Profile.backToSignInPrompt,
                    actionTitle: L10n.Profile.backToSignInButton
                ) {
                    store.send(.flowChanged(.auth))
                }
            }
        }
    }

    private var verificationPendingCard: some View {
        authCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                stepHeader(
                    current: 3,
                    total: 3,
                    title: L10n.Profile.verificationRequiredTitle,
                    body: L10n.Profile.verificationPendingBody(
                        store.verificationRequiredEmail ?? store.email
                    )
                )

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

                Divider()

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(L10n.Profile.manualVerificationHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    authFieldGroup {
                        authField(
                            title: L10n.Profile.verificationTokenPlaceholder,
                            content: AnyView(
                                TextField(
                                    L10n.Profile.verificationTokenPlaceholder,
                                    text: verificationTokenBinding
                                )
                                .appNeverAutocapitalized()
                                .autocorrectionDisabled()
                            )
                        )
                    }

                    primaryButton(
                        title: L10n.Profile.verifyEmailButton,
                        isLoading: store.isSubmitting
                    ) {
                        store.send(.verifyEmailTapped)
                    }
                }

                inlineActionRow(
                    prompt: L10n.Profile.backToSignInPrompt,
                    actionTitle: L10n.Profile.backToSignInButton
                ) {
                    store.send(.flowChanged(.auth))
                }
            }
        }
    }

    private var signedInHeader: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(L10n.Profile.title)
                .font(.system(size: 38, weight: .bold, design: .rounded))

            if let session = store.session {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text(displayName(for: session.email))
                        .font(.title3.weight(.semibold))
                    Text(session.email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                    tint: .red
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

    private func authCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            content()
        }
        .padding(AppSpacing.xLarge)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: AppStrokeWidth.standard)
        }
    }

    private func sectionTitle(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.title3.weight(.semibold))

            Text(body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func stepHeader(current: Int, total: Int, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(spacing: AppSpacing.small) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < current ? Color.accentColor : Color.secondary.opacity(0.18))
                        .frame(height: 6)
                }
            }

            sectionTitle(title: title, body: body)
        }
    }

    private func authFieldGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            content()
        }
    }

    private func authField(title: String, content: AnyView) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            content
                .padding(AppSpacing.large)
                .background(Color.white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        }
    }

    private func inlineActionRow(
        prompt: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: AppSpacing.small) {
            Text(prompt)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(actionTitle, action: action)
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
        }
    }

    private func statusBanner(message: String, tint: Color) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
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

    private func settingsRow(
        title: String,
        systemImage: String,
        tint: Color = .primary
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

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var heroTitle: String {
        switch (store.flow, store.mode) {
        case (.auth, .login):
            return L10n.Profile.loginHeroTitle
        case (.auth, .register):
            return L10n.Profile.registerHeroTitle
        case (.forgotPassword, _):
            return L10n.Profile.forgotPasswordHeroTitle
        case (.verificationPending, _):
            return L10n.Profile.verifyHeroTitle
        }
    }

    private var heroBody: String {
        switch (store.flow, store.mode) {
        case (.auth, .login):
            return L10n.Profile.loginHeroBody
        case (.auth, .register):
            return L10n.Profile.registerHeroBody
        case (.forgotPassword, _):
            return L10n.Profile.forgotPasswordHeroBody
        case (.verificationPending, _):
            return L10n.Profile.verifyHeroBody
        }
    }

    private func displayName(for email: String) -> String {
        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        return localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
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

#Preview("Auth") {
    ProfileSheetView(
        onClose: {},
        store: Store(initialState: AuthState()) {
            AuthReducer()
        }
    )
}
