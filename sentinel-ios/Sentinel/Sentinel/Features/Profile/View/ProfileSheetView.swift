import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<ProfileFeature>

    private var promptBinding: Binding<String> {
        Binding(
            get: { store.defaultPromptTemplate },
            set: { store.send(.defaultPromptChanged($0)) }
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
                    ProfileHeader(displayName: store.displayName, email: store.userEmail ?? "")

                    if let errorMessage = store.errorMessage {
                        statusBanner(errorMessage, tint: .red.opacity(0.12), foreground: .red)
                    }

                    if let statusMessage = store.statusMessage {
                        statusBanner(statusMessage, tint: .secondary.opacity(0.12), foreground: .secondary)
                    }

                    promptSection
                    achievementsSection
                    accountSection
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.large)
                .padding(.bottom, AppSpacing.xLarge)
            }
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
                store.send(.onAppear)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var promptSection: some View {
        SettingsSectionCard(
            title: L10n.Settings.defaultPromptTitle,
            footer: L10n.Settings.defaultPromptFooter
        ) {
            TextField(L10n.Settings.defaultPromptTitle, text: promptBinding, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(AppSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPlatformColor.systemGroupedBackground)
                )

            Divider()
                .padding(.horizontal, AppSpacing.large)

            PrimaryButton(L10n.Settings.savePromptButton, isEnabled: !store.isSavingPrompt) {
                store.send(.savePromptTapped)
            }
            .padding(AppSpacing.large)
        }
    }

    private var achievementsSection: some View {
        SettingsSectionCard(title: L10n.Settings.achievements) {
            if let accessToken = store.accessToken {
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
    }

    private var accountSection: some View {
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
                store.send(.deletePromptVisibilityChanged(!store.isDeletePromptVisible))
            }

            if store.isDeletePromptVisible {
                Divider()
                    .padding(.horizontal, AppSpacing.large)

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text(L10n.Profile.deleteAccountBody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    SecureField(L10n.Profile.deleteAccountPasswordPlaceholder, text: deletePasswordBinding)
                        .padding(.horizontal, AppSpacing.large)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppPlatformColor.systemGroupedBackground)
                        )

                    HStack(spacing: AppSpacing.medium) {
                        Button(L10n.Profile.cancelButton) {
                            store.send(.deletePromptVisibilityChanged(false))
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

    private func statusBanner(_ message: String, tint: Color, foreground: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
