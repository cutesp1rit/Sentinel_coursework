import ComposableArchitecture
import Foundation

struct HomeReducer: Reducer {
    @Dependency(\.achievementsClient) var achievementsClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    typealias State = HomeState
    typealias Action = HomeAction

    var body: some Reducer<HomeState, HomeAction> {
        Reduce { state, action in
            switch action {
            case .chatTapped, .profileTapped, .rebalanceTapped:
                return .none

            case .achievementsFailed:
                return .none

            case let .achievementsLoaded(groups):
                state.achievementGroups = groups
                return .none

            case let .daySelected(dayID):
                state.selectedDayID = dayID
                return .none

            case .onAppear:
                guard state.isAuthenticated else { return .none }
                guard !state.schedule.isLoading else { return .none }
                state.schedule.isLoading = true
                state.schedule.errorMessage = nil
                let accessToken = state.accessToken
                return .merge(
                    .run { [calendarSyncClient] send in
                        let snapshot = await calendarSyncClient.loadUpcoming()
                        await send(.scheduleLoaded(snapshot))
                    },
                    .run { [achievementsClient] send in
                        guard let accessToken else { return }
                        do {
                            let groups = try await achievementsClient.loadAchievements(accessToken)
                            await send(.achievementsLoaded(groups))
                        } catch {
                            let message = (error as? APIError)?.message ?? error.localizedDescription
                            await send(.achievementsFailed(message))
                        }
                    }
                )

            case let .sessionChanged(session):
                let previousToken = state.accessToken
                state.accessToken = session?.accessToken
                state.userEmail = session?.email
                if session == nil {
                    state.achievementGroups = []
                    state.schedule = HomeScheduleState()
                }
                if previousToken != state.accessToken, state.accessToken != nil {
                    return .send(.onAppear)
                }
                return .none

            case let .scheduleLoadFailed(message):
                state.schedule.isLoading = false
                state.schedule.errorMessage = message
                return .none

            case let .scheduleLoaded(snapshot):
                state.schedule.isLoading = false
                state.schedule.errorMessage = nil
                state.schedule.access = switch snapshot.access {
                case .denied:
                    .denied
                case .granted:
                    .granted
                case .notRequested:
                    .notRequested
                }
                state.schedule.upcomingItems = snapshot.items.map { item in
                    HomeScheduleItem(
                        endDate: item.endAt,
                        startDate: item.startAt,
                        title: item.title,
                        timeText: Self.timeText(startAt: item.startAt, endAt: item.endAt),
                        subtitle: item.subtitle.isEmpty ? "Calendar" : item.subtitle
                    )
                }
                return .none
            }
        }
    }
}

private extension HomeReducer {
    static func timeText(startAt: Date, endAt: Date?) -> String {
        if let endAt {
            return "\(startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        return startAt.formatted(date: .abbreviated, time: .shortened)
    }
}
