import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    let onLogout: () -> Void
    let store: StoreOf<SettingsReducer>

    var body: some View {
        List {
            Section(L10n.Settings.defaultPromptTitle) {
                TextEditor(
                    text: Binding(
                        get: { store.defaultPromptTemplate },
                        set: { store.send(.defaultPromptChanged($0)) }
                    )
                )
                .frame(minHeight: 140)

                Button(L10n.Settings.savePromptButton) {
                    store.send(.savePromptTapped)
                }

                Text(L10n.Settings.defaultPromptFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                if let accessToken = store.accessToken {
                    NavigationLink(L10n.Settings.achievements) {
                        AchievementsView(
                            store: Store(initialState: AchievementsState(accessToken: accessToken)) {
                                AchievementsReducer()
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
