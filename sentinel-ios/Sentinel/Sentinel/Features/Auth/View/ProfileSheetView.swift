import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<AuthReducer>

    @State private var isDeletePromptVisible = false

    private var sessionEmail: String {
        store.session?.email ?? store.settings.userEmail ?? ""
    }

    private var displayName: String {
        let localPart = sessionEmail.split(separator: "@").first.map(String.init) ?? L10n.App.title
        let normalized = localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
        return normalized.isEmpty ? L10n.App.title : normalized
    }

    private var defaultPromptBinding: Binding<String> {
        Binding(
            get: { store.settings.defaultPromptTemplate },
            set: { store.send(.settings(.defaultPromptChanged($0))) }
        )
    }

    private var deletePasswordBinding: Binding<String> {
        Binding(
            get: { store.deleteAccountPassword },
            set: { store.send(.deleteAccountPasswordChanged($0)) }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    ProfileHeader(displayName: displayName, email: sessionEmail)

                    if let errorMessage = store.errorMessage {
                        profileBanner(errorMessage, tint: .red.opacity(0.12), foreground: .red)
                    }

                    if let statusMessage = store.settings.statusMessage {
                        profileBanner(statusMessage, tint: .secondary.opacity(0.12), foreground: .secondary)
                    }

                    SettingsSectionCard(
                        title: L10n.Settings.defaultPromptTitle,
                        footer: L10n.Settings.defaultPromptFooter
                    ) {
                        TextField(
                            L10n.Settings.defaultPromptTitle,
                            text: defaultPromptBinding,
                            axis: .vertical
                        )
                        .textFieldStyle(.plain)
                        .padding(AppSpacing.large)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AppPlatformColor.systemGroupedBackground)
                        )

                        Divider()
                            .padding(.horizontal, AppSpacing.large)

                        PrimaryButton(L10n.Settings.savePromptButton, isEnabled: !store.settings.isLoading) {
                            store.send(.settings(.savePromptTapped))
                        }
                        .padding(AppSpacing.large)
                    }

                    SettingsSectionCard(title: L10n.Settings.achievements) {
                        if let accessToken = store.settings.accessToken {
                            NavigationLink {
                                AchievementsView(
                                    store: Store(initialState: AchievementsState(accessToken: accessToken)) {
                                        AchievementsReducer()
                                    }
                                )
                            } label: {
                                SettingsRow(systemImage: "rosette", title: L10n.Settings.achievements) {
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    SettingsSectionCard(title: L10n.Profile.accountActionsTitle) {
                        AccountActionRow(
                            title: L10n.Profile.logoutButton,
                            systemImage: "rectangle.portrait.and.arrow.right",
                            role: nil,
                            tint: .primary
                        ) {
                            store.send(.logoutTapped)
                        }

                        Divider()
                            .padding(.horizontal, AppSpacing.large)

                        AccountActionRow(
                            title: L10n.Profile.deleteAccountButton,
                            systemImage: "trash",
                            role: .destructive,
                            tint: .red
                        ) {
                            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                                isDeletePromptVisible.toggle()
                            }
                        }

                        if isDeletePromptVisible {
                            Divider()
                                .padding(.horizontal, AppSpacing.large)

                            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                                Text(L10n.Profile.deleteAccountBody)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                SecureField(
                                    L10n.Profile.deleteAccountPasswordPlaceholder,
                                    text: deletePasswordBinding
                                )
                                .textContentType(.password)
                                .padding(.horizontal, AppSpacing.large)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(AppPlatformColor.systemGroupedBackground)
                                )

                                HStack(spacing: AppSpacing.medium) {
                                    Button(L10n.Profile.cancelButton) {
                                        withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                                            isDeletePromptVisible = false
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.subheadline.weight(.semibold))

                                    Spacer()

                                    Button(L10n.Profile.deleteAccountConfirmButton, role: .destructive) {
                                        store.send(.deleteAccountTapped)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.subheadline.weight(.semibold))
                                }
                            }
                            .padding(AppSpacing.large)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)
                .padding(.bottom, AppSpacing.xLarge)
            }
            .scrollIndicators(.hidden)
            .background(HomeTopGradientBackground().ignoresSafeArea())
            .navigationTitle(L10n.Profile.title)
            .sentinelInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                    Button(L10n.Profile.closeButton, action: onClose)
                        .buttonStyle(.plain)
                }
            }
            .task {
                store.send(.settings(.onAppear))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func profileBanner(
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
}

#Preview("Profile") {
    var state = AuthState()
    state.session = AuthenticatedSession(
        session: Session(accessToken: "preview", tokenType: "Bearer"),
        email: "alex@example.com"
    )
    state.settings.accessToken = "preview"
    state.settings.userEmail = "alex@example.com"

    return ProfileSheetView(
        onClose: {},
        store: Store(initialState: state) {
            AuthReducer()
        }
    )
}
