import ComposableArchitecture
import Foundation

@Reducer
struct AchievementsReducer {
    @Dependency(\.achievementsClient) var achievementsClient

    var body: some Reducer<AchievementsState, AchievementsAction> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.hasLoaded, !state.isLoading else { return .none }
                return loadAchievements(state: &state)

            case .retryTapped:
                guard !state.isLoading else { return .none }
                return loadAchievements(state: &state)

            case let .achievementsFailed(message):
                state.errorMessage = message
                state.isLoading = false
                return .none

            case let .achievementsLoaded(groups):
                state.errorMessage = nil
                state.groups = groups
                state.hasLoaded = true
                state.isLoading = false
                return .none
            }
        }
    }

    private func loadAchievements(state: inout AchievementsState) -> Effect<AchievementsAction> {
        state.errorMessage = nil
        state.isLoading = true
        let accessToken = state.accessToken

        return .run { [achievementsClient] send in
            do {
                let groups = try await achievementsClient.loadAchievements(accessToken)
                await send(.achievementsLoaded(groups))
            } catch {
                let message: String
                if let apiError = error as? APIError {
                    message = apiError.message
                } else {
                    message = error.localizedDescription
                }
                await send(.achievementsFailed(message))
            }
        }
    }
}
