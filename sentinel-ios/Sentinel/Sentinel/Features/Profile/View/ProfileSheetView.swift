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
            List {
                Section {
                    ProfileHeader(displayName: store.displayName, email: store.userEmail ?? "")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        statusBanner(errorMessage, tint: .red.opacity(0.12), foreground: .red)
                    }
                }

                if let statusMessage = store.statusMessage {
                    Section {
                        statusBanner(statusMessage, tint: .secondary.opacity(0.12), foreground: .secondary)
                    }
                }

                Section(L10n.Settings.defaultPromptTitle) {
                    TextField(L10n.Settings.defaultPromptTitle, text: promptBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.vertical, AppSpacing.small)

                    Text(L10n.Settings.defaultPromptFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    PrimaryButton(L10n.Settings.savePromptButton, isEnabled: !store.isSavingPrompt) {
                        store.send(.savePromptTapped)
                    }
                    .listRowInsets(EdgeInsets(top: AppSpacing.small, leading: AppSpacing.medium, bottom: AppSpacing.small, trailing: AppSpacing.medium))
                    .listRowBackground(Color.clear)
                }

                if let accessToken = store.accessToken {
                    Section(L10n.Settings.achievements) {
                        NavigationLink {
                            AchievementsView(
                                store: Store(initialState: AchievementsState(accessToken: accessToken)) {
                                    AchievementsReducer()
                                }
                            )
                        } label: {
                            Text(L10n.Settings.achievements)
                        }
                    }
                }

                Section(L10n.Profile.accountActionsTitle) {
                    Button(L10n.Profile.logoutButton) {
                        store.send(.logoutTapped)
                    }
                    .foregroundStyle(.primary)

                    Button(L10n.Profile.deleteAccountButton, role: .destructive) {
                        store.send(.deletePromptVisibilityChanged(!store.isDeletePromptVisible))
                    }

                    if store.isDeletePromptVisible {
                        SecureField(L10n.Profile.deleteAccountPasswordPlaceholder, text: deletePasswordBinding)
                        Button(L10n.Profile.deleteAccountConfirmButton, role: .destructive) {
                            store.send(.deleteAccountTapped)
                        }
                        Button(L10n.Profile.cancelButton) {
                            store.send(.deletePromptVisibilityChanged(false))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
