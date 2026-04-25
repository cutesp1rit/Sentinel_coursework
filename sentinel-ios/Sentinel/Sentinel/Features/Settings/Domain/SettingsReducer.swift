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

            case let .notificationsToggleChanged(isEnabled):
                state.notificationsEnabled = isEnabled
                state.statusMessage = nil
                return .run { send in
                    @Dependency(\.appSettingsClient) var appSettingsClient
                    @Dependency(\.localNotificationsClient) var localNotificationsClient

                    let granted = isEnabled ? await localNotificationsClient.requestAuthorization() : false
                    var settings = await appSettingsClient.load()
                    settings.notificationsEnabled = isEnabled && granted
                    await appSettingsClient.save(settings)

                    if !settings.notificationsEnabled {
                        await localNotificationsClient.removeAllSentinelRequests()
                    }

                    if isEnabled && !granted {
                        await send(.statusMessageUpdated(L10n.Settings.notificationsDenied))
                    } else {
                        await send(.statusMessageUpdated(nil))
                    }
                    await send(.settingsLoaded(settings))
                }

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
                state.notificationsEnabled = settings.notificationsEnabled
                return .none

            case let .statusMessageUpdated(message):
                state.statusMessage = message
                return .none
            }
        }
    }
}
