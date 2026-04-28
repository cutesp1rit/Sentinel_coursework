import ComposableArchitecture
import Foundation

@Reducer
struct ProfileFeature {
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.sessionStorageClient) var sessionStorageClient

    @ObservableState
    struct State: Equatable {
        var accessToken: String?
        var deleteAccountPassword = ""
        var defaultPromptTemplate = ""
        var errorMessage: String?
        var isDeletePromptVisible = false
        var isDeletingAccount = false
        var isLoading = false
        var isSavingPrompt = false
        var lastSavedDefaultPromptTemplate = ""
        var selectedEnvironment: AppEnvironment = .local
        var userEmail: String?

        var displayName: String {
            let localPart = userEmail?.split(separator: "@").first.map(String.init) ?? L10n.App.title
            let normalized = localPart
                .replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return normalized.isEmpty ? L10n.App.title : normalized
        }
    }

    enum Action: Equatable {
        case deleteAccountCompleted
        case deleteAccountFailed(String)
        case deleteAccountPasswordChanged(String)
        case deleteAccountTapped
        case deletePromptVisibilityChanged(Bool)
        case defaultPromptChanged(String)
        case environmentChanged(AppEnvironment)
        case loaded(AppSettings)
        case logoutFailed(String)
        case logoutTapped
        case onAppear
        case promptEditingEnded
        case promptPersisted(String)
        case sessionChanged(AuthenticatedSession?)
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case sessionEnded
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .deleteAccountCompleted:
                return .send(.delegate(.sessionEnded))

            case let .deleteAccountFailed(message), let .logoutFailed(message):
                state.errorMessage = message
                state.isDeletingAccount = false
                state.isLoading = false
                return .none

            case let .deleteAccountPasswordChanged(password):
                state.deleteAccountPassword = password
                state.errorMessage = nil
                return .none

            case .deleteAccountTapped:
                guard let accessToken = state.accessToken else { return .none }
                let password = state.deleteAccountPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !password.isEmpty else {
                    state.errorMessage = L10n.Profile.deleteAccountPasswordRequired
                    return .none
                }
                state.errorMessage = nil
                state.isDeletingAccount = true
                return .run { [authClient, sessionStorageClient] send in
                    do {
                        try await authClient.deleteAccount(password, accessToken)
                        try sessionStorageClient.clear()
                        await send(.deleteAccountCompleted)
                    } catch {
                        await send(.deleteAccountFailed(Self.errorMessage(for: error)))
                    }
                }

            case let .deletePromptVisibilityChanged(isVisible):
                state.isDeletePromptVisible = isVisible
                return .none

            case let .defaultPromptChanged(value):
                state.defaultPromptTemplate = value
                return .none

            case let .environmentChanged(environment):
                guard environment.isSelectable else { return .none }
                state.selectedEnvironment = environment
                return .run { [appSettingsClient] send in
                    var settings = await appSettingsClient.load()
                    settings.selectedEnvironment = environment
                    await appSettingsClient.save(settings)
                    await send(.loaded(settings))
                }

            case let .loaded(settings):
                state.defaultPromptTemplate = settings.defaultPromptTemplate
                state.lastSavedDefaultPromptTemplate = settings.defaultPromptTemplate
                state.selectedEnvironment = settings.selectedEnvironment
                state.isLoading = false
                state.isSavingPrompt = false
                return .none

            case .logoutTapped:
                state.errorMessage = nil
                state.isLoading = true
                return .run { [sessionStorageClient] send in
                    do {
                        try sessionStorageClient.clear()
                        await send(.delegate(.sessionEnded))
                    } catch {
                        await send(.logoutFailed(Self.errorMessage(for: error)))
                    }
                }

            case .onAppear:
                guard state.accessToken != nil else { return .none }
                state.isLoading = true
                return .run { [appSettingsClient] send in
                    let settings = await appSettingsClient.load()
                    await send(.loaded(settings))
                }

            case .promptEditingEnded:
                let prompt = state.defaultPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                guard prompt != state.lastSavedDefaultPromptTemplate else { return .none }
                state.isSavingPrompt = true
                return .run { [appSettingsClient] send in
                    var settings = await appSettingsClient.load()
                    settings.defaultPromptTemplate = prompt
                    await appSettingsClient.save(settings)
                    await send(.promptPersisted(prompt))
                }

            case let .promptPersisted(prompt):
                state.lastSavedDefaultPromptTemplate = prompt
                state.defaultPromptTemplate = prompt
                state.isSavingPrompt = false
                return .none

            case let .sessionChanged(session):
                state.accessToken = session?.accessToken
                state.userEmail = session?.email
                if session == nil {
                    state = State()
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private extension ProfileFeature {
    static func errorMessage(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }
}
