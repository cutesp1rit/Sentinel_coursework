import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct HomeReducerExtraBranchCoverageTests {
    @Test
    func homeReducerNoopAndDirectMutationBranchesStayStable() async {
        var state = HomeState()
        state.accessToken = "token"
        state.calendar = CalendarState(accessToken: "old")
        state.achievements = AchievementsState(accessToken: "old")
        state.battery = .ready(.init(headline: "80%", detail: "Ready", percentage: 80))

        let store = TestStore(initialState: state) {
            HomeReducer()
        }
        store.exhaustivity = .off

        await store.send(.achievementsFailed("ignored"))
        #expect(store.state.achievementGroups.isEmpty)

        await store.send(.calendarNavigationChanged(false)) {
            $0.calendar = nil
        }

        await store.send(.achievementsNavigationChanged(false)) {
            $0.achievements = nil
        }

        await store.send(.allEventsTapped)
        #expect(store.state.calendar?.accessToken == "token")

        await store.send(.achievementsTapped)
        #expect(store.state.achievements?.accessToken == "token")

        await store.send(.batteryUpdated(.hidden)) {
            $0.battery = .hidden
        }
    }

    @Test
    func sessionChangedWithSameTokenAndSignedOutBatteryRefreshNoop() async {
        let signedOut = HomeState()
        let signedOutStore = TestStore(initialState: signedOut) {
            HomeReducer()
        }
        await signedOutStore.send(.batteryRefreshRequested)

        var sameTokenState = HomeState()
        sameTokenState.accessToken = "token"
        let session = AuthenticatedSession(session: Session(accessToken: "token", tokenType: "bearer"), email: "jane@example.com")
        let sameTokenStore = TestStore(initialState: sameTokenState) {
            HomeReducer()
        }
        await sameTokenStore.send(.sessionChanged(session)) {
            $0.accessToken = "token"
            $0.userEmail = "jane@example.com"
        }
    }
}
