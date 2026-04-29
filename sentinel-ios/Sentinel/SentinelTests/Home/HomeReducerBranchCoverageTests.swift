import SentinelUI
import SentinelCore
import SentinelPlatformiOS
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct HomeReducerBranchCoverageTests {
    @Test
    func signedOutBranchesAndSimpleNoopsStayStable() async {
        let store = TestStore(initialState: HomeState()) {
            HomeReducer()
        }

        await store.send(.onAppear)
        await store.send(.batteryRefreshRequested)
        await store.send(.allEventsTapped)
        await store.send(.achievementsTapped)
        await store.send(.chatTapped)
        await store.send(.createAccountTapped)
        await store.send(.profileTapped)
        await store.send(.rebalanceTapped)
        await store.send(.signInTapped)
    }

    @Test
    func authenticatedBranchesCoverBatteryAchievementsScheduleAndSessionRestore() async {
        let groups = [Fixture.achievementGroup(groupCode: "active_days", currentValue: 3)]
        let snapshot = CalendarSyncClient.UpcomingSnapshot(
            access: .notRequested,
            items: []
        )

        var initialState = HomeState()
        initialState.accessToken = "token"

        let store = TestStore(initialState: initialState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .ready(.init(headline: "61%", detail: "Stable", percentage: 61)) }
            $0.calendarSyncClient.loadUpcoming = { snapshot }
            $0.achievementsClient.loadAchievements = { _ in groups }
        }
        store.exhaustivity = .off

        await store.send(.batteryRefreshRequested)
        await store.receive(.batteryUpdated(.ready(.init(headline: "61%", detail: "Stable", percentage: 61)))) {
            $0.battery = .ready(.init(headline: "61%", detail: "Stable", percentage: 61))
        }

        await store.send(.achievementsLoaded(groups)) {
            $0.achievementGroups = groups
        }

        await store.send(.scheduleLoadFailed("Schedule failed")) {
            $0.schedule.isLoading = false
            $0.schedule.errorMessage = "Schedule failed"
        }

        await store.send(.daySelected(3)) {
            $0.selectedDayID = 3
        }

        var nilTokenState = HomeState()
        nilTokenState.accessToken = nil
        let restoreStore = TestStore(initialState: nilTokenState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .hidden }
            $0.calendarSyncClient.loadUpcoming = { snapshot }
            $0.achievementsClient.loadAchievements = { _ in groups }
        }
        restoreStore.exhaustivity = .off

        await restoreStore.send(.sessionChanged(Fixture.authenticatedSession())) {
            $0.accessToken = "access-token"
            $0.userEmail = "jane.doe@example.com"
        }
        await restoreStore.receive(.onAppear) {
            $0.schedule.isLoading = true
            $0.schedule.errorMessage = nil
        }
    }
}
