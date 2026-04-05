import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<AuthReducer>

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
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
    }

    private var emailBinding: Binding<String> {
        Binding(
            get: { store.email },
            set: { store.send(.emailChanged($0)) }
        )
    }

    private var modeBinding: Binding<AuthState.Mode> {
        Binding(
            get: { store.mode },
            set: { store.send(.modeChanged($0)) }
        )
    }

    private var passwordBinding: Binding<String> {
        Binding(
            get: { store.password },
            set: { store.send(.passwordChanged($0)) }
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
                        .font(.system(size: 40))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var authForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Picker(
                L10n.Profile.modePickerLabel,
                selection: modeBinding
            ) {
                Text(L10n.Profile.loginMode).tag(AuthState.Mode.login)
                Text(L10n.Profile.registerMode).tag(AuthState.Mode.register)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                TextField(
                    L10n.Profile.emailPlaceholder,
                    text: emailBinding
                )
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .autocorrectionDisabled()
                .padding(AppSpacing.large)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                SecureField(
                    L10n.Profile.passwordPlaceholder,
                    text: passwordBinding
                )
                .textContentType(.password)
                .padding(AppSpacing.large)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            }

            Button {
                store.send(.submitTapped)
            } label: {
                HStack {
                    if store.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(store.mode == .login ? L10n.Profile.loginButton : L10n.Profile.registerButton)
                        .frame(maxWidth: .infinity)
                }
                .font(.body.weight(.semibold))
                .padding(.vertical, AppSpacing.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSubmitting || store.isRestoring)

            Text(L10n.Profile.authHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var signedInActions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            NavigationLink {
                if let accessToken = store.session?.accessToken {
                    AchievementsView(
                        store: Store(
                            initialState: AchievementsState(accessToken: accessToken)
                        ) {
                            AchievementsReducer()
                        }
                    )
                }
            } label: {
                settingsRow(
                    title: L10n.Achievements.title,
                    systemImage: "rosette"
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                store.send(.logoutTapped)
            } label: {
                settingsRow(
                    title: L10n.Profile.logoutButton,
                    systemImage: "rectangle.portrait.and.arrow.right",
                    tint: .red,
                    trailing: store.isSubmitting ? AnyView(ProgressView()) : AnyView(EmptyView())
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isSubmitting)

            Text(L10n.Profile.logoutHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
        trailing: AnyView = AnyView(Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary))
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: AppGrid.value(8), height: AppGrid.value(8))
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            Text(title)
                .font(.body)
                .foregroundStyle(tint)

            Spacer()

            trailing
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.large)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
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
