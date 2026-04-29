import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct HomeProfileNavigationFeatureTests {
    @Test
    func homeOpensAndClosesCalendarAndAchievementsThroughParentState() async {
        var initialState = HomeState()
        initialState.accessToken = "token"

        let store = TestStore(initialState: initialState) {
            HomeReducer()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .hidden }
            $0.calendarSyncClient.loadUpcoming = { .init(access: .notRequested, items: []) }
            $0.achievementsClient.loadAchievements = { _ in [] }
            $0.eventsClient.listEvents = { _, _, _ in [] }
            $0.batteryClient.evaluateDay = { _ in .hidden }
            $0.calendarSyncClient.sync = { _ in .init() }
        }
        store.exhaustivity = .off

        await store.send(.calendarNavigationChanged(true))
        await store.receive(.allEventsTapped)
        #expect(store.state.calendar?.accessToken == "token")

        await store.send(.achievementsNavigationChanged(true))
        await store.receive(.achievementsTapped)
        #expect(store.state.achievements?.accessToken == "token")

        await store.send(.calendarNavigationChanged(false)) {
            $0.calendar = nil
        }

        await store.send(.achievementsNavigationChanged(false)) {
            $0.achievements = nil
        }
    }

    @Test
    func profileOpensAndClosesAchievementsThroughParentState() async {
        var initialState = ProfileFeature.State()
        initialState.accessToken = "token"

        let store = TestStore(initialState: initialState) {
            ProfileFeature()
        } withDependencies: {
            $0.appSettingsClient.load = { await MainActor.run { .defaultValue } }
            $0.appSettingsClient.save = { _ in }
            $0.sessionStorageClient.clear = {}
            $0.authClient.deleteAccount = { _, _ in }
            $0.achievementsClient.loadAchievements = { _ in [] }
        }
        store.exhaustivity = .off

        await store.send(.achievementsNavigationChanged(true))
        await store.receive(.achievementsTapped)
        #expect(store.state.achievements?.accessToken == "token")

        await store.send(.achievementsNavigationChanged(false)) {
            $0.achievements = nil
        }
    }
}
