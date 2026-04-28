import ComposableArchitecture
import Foundation

@Reducer
struct SettingsReducer {
    var body: some Reducer<SettingsState, SettingsAction> {
        Reduce { state, action in
            switch action {
            case let .defaultPromptChanged(value):
                state.defaultPromptTemplate = value
                state.statusMessage = nil
                return .none

            case .onAppear:
                state.isLoading = true
                return .run { send in
                    @Dependency(\.appSettingsClient) var appSettingsClient
                    let settings = await appSettingsClient.load()
                    await send(.settingsLoaded(settings))
                }

            case .promptSaved:
                state.statusMessage = L10n.Settings.savedStatus
                return .none

            case .savePromptTapped:
                let prompt = state.defaultPromptTemplate
                state.statusMessage = nil
                return .run { send in
                    @Dependency(\.appSettingsClient) var appSettingsClient
                    var settings = await appSettingsClient.load()
                    settings.defaultPromptTemplate = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    await appSettingsClient.save(settings)
                    await send(.promptSaved)
                }

            case let .settingsLoaded(settings):
                state.defaultPromptTemplate = settings.defaultPromptTemplate
                state.isLoading = false
                return .none
            }
        }
    }
}
