import ComposableArchitecture
import SwiftUI

struct ProfileSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<ProfileFeature>
    @FocusState private var isPromptFocused: Bool

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

                #if DEBUG
                Section {
                    NavigationLink {
                        EnvironmentSelectionView(
                            selectedEnvironment: store.selectedEnvironment,
                            onSelect: { store.send(.environmentChanged($0)) }
                        )
                    } label: {
                        HStack {
                            Text(L10n.Profile.environmentTitle)
                            Spacer()
                            Text(environmentTitle(store.selectedEnvironment))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                #endif

                Section(L10n.Settings.defaultPromptTitle) {
                    TextEditor(text: promptBinding)
                        .frame(minHeight: 132)
                        .focused($isPromptFocused)
                        .onChange(of: isPromptFocused) { _, isFocused in
                            if !isFocused {
                                store.send(.promptEditingEnded)
                            }
                        }

                    Text(L10n.Settings.defaultPromptFooter)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let accessToken = store.accessToken {
                    Section {
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

                Section {
                    NavigationLink {
                        LegalDocumentsView()
                    } label: {
                        Text(L10n.Profile.legalTitle)
                    }
                }

                Section {
                    Button(L10n.Profile.logoutButton) {
                        store.send(.promptEditingEnded)
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
            .background(AppPlatformColor.systemGroupedBackground.ignoresSafeArea())
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
            .onDisappear {
                store.send(.promptEditingEnded)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    private func environmentTitle(_ environment: AppEnvironment) -> String {
        switch environment {
        case .local:
            return L10n.Profile.environmentLocal
        case .testing:
            return L10n.Profile.environmentTesting
        case .production:
            return L10n.Profile.environmentProduction
        }
    }
}
