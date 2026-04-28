import ComposableArchitecture
import Foundation

struct HomeReducer: Reducer {
    @Dependency(\.achievementsClient) var achievementsClient
    @Dependency(\.batteryClient) var batteryClient
    @Dependency(\.calendarSyncClient) var calendarSyncClient

    typealias State = HomeState
    typealias Action = HomeAction

    var body: some Reducer<HomeState, HomeAction> {
        Reduce { state, action in
            switch action {
            case .chatTapped, .createAccountTapped, .profileTapped, .rebalanceTapped, .signInTapped:
                return .none

            case .batteryRefreshRequested:
                guard state.isAuthenticated else { return .none }
                return Self.evaluateBatteryEffect(
                    batteryClient: batteryClient,
                    items: state.schedule.upcomingItems,
                    access: state.schedule.access
                )

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
                var effects: [Effect<Action>] = [
                    Self.evaluateBatteryEffect(
                        batteryClient: batteryClient,
                        items: state.schedule.upcomingItems,
                        access: state.schedule.access
                    )
                ]

                let accessToken = state.accessToken
                if !state.schedule.isLoading {
                    state.schedule.isLoading = true
                    state.schedule.errorMessage = nil
                    effects.append(
                        .run { [calendarSyncClient] send in
                            let snapshot = await calendarSyncClient.loadUpcoming()
                            await send(.scheduleLoaded(snapshot))
                        }
                    )
                    effects.append(
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
                }

                return .merge(effects)

            case let .sessionChanged(session):
                let previousToken = state.accessToken
                state.accessToken = session?.accessToken
                state.userEmail = session?.email
                if session == nil {
                    state.achievementGroups = []
                    state.schedule = HomeScheduleState()
                    state.battery = .hidden
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
                        id: item.id,
                        endDate: item.endAt,
                        startDate: item.startAt,
                        title: item.title,
                        timeText: Self.timeText(startAt: item.startAt, endAt: item.endAt),
                        subtitle: item.subtitle.isEmpty ? "Calendar" : item.subtitle
                    )
                }
                let access = state.schedule.access
                let items = state.schedule.upcomingItems
                return Self.evaluateBatteryEffect(
                    batteryClient: batteryClient,
                    items: items,
                    access: access
                )

            case let .batteryUpdated(battery):
                state.battery = battery
                return .none
            }
        }
    }
}
