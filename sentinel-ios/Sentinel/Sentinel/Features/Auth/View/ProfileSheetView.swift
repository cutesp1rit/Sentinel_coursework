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
            .navigationBarTitleDisplayMode(.inline)
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
            Text(store.isAuthenticated ? L10n.Profile.signedInTitle : L10n.Profile.signedOutTitle)
                .font(.headline)

            if store.isRestoring {
                HStack(spacing: AppSpacing.medium) {
                    ProgressView()
                    Text(L10n.Profile.restoringStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if let session = store.session {
                Text(session.email)
                    .font(.body.weight(.semibold))

                Text(L10n.Profile.sessionStoredBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
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
                HStack {
                    Label(L10n.Achievements.title, systemImage: "rosette")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.body.weight(.semibold))
                .padding(.vertical, AppSpacing.large)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                store.send(.logoutTapped)
            } label: {
                HStack {
                    if store.isSubmitting {
                        ProgressView()
                    }

                    Text(L10n.Profile.logoutButton)
                        .frame(maxWidth: .infinity)
                }
                .font(.body.weight(.semibold))
                .padding(.vertical, AppSpacing.large)
            }
            .buttonStyle(.bordered)
            .disabled(store.isSubmitting)

            Text(L10n.Profile.logoutHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
