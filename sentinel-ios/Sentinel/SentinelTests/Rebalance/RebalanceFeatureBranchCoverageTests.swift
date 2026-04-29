import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct RebalanceFeatureBranchCoverageTests {
    @Test
    func dayBatteryRequestGuardAndCacheBranchesAvoidDuplicateWork() async {
        let request = BatteryDayRequest(
            dayID: "day-1",
            endDate: Fixture.secondaryDate,
            entries: [],
            startDate: Fixture.referenceDate
        )
        let day = RebalanceFeature.State.DayItem(
            batteryRequest: request,
            id: "day-1",
            date: Fixture.referenceDate,
            eventCount: 0,
            isToday: true
        )

        var loadingState = RebalanceFeature.State(accessToken: "token")
        loadingState.availableDays = [day]
        loadingState.dayBatteryCache["day-1"] = .init(signature: request.signature, state: .loading)

        let store = TestStore(initialState: loadingState) {
            RebalanceFeature()
        }

        await store.send(.dayBatteryRequested("missing"))
        await store.send(.dayBatteryRequested("day-1"))
        #expect(store.state.activeDayBatteryID == nil)

        var readyState = RebalanceFeature.State(accessToken: "token")
        readyState.availableDays = [day]
        readyState.dayBatteryCache["day-1"] = .init(signature: request.signature, state: .ready(70))
        let readyStore = TestStore(initialState: readyState) {
            RebalanceFeature()
        }
        await readyStore.send(.dayBatteryRequested("day-1"))
        #expect(readyStore.state.dayBatteryCache["day-1"]?.state == .ready(70))
    }

    @Test
    func togglesPreviewAndFailureBranchesResetTransientState() async {
        let request = BatteryDayRequest(
            dayID: "day-1",
            endDate: Fixture.secondaryDate,
            entries: [],
            startDate: Fixture.referenceDate
        )
        let day = RebalanceFeature.State.DayItem(
            batteryRequest: request,
            id: "day-1",
            date: Fixture.referenceDate,
            eventCount: 0,
            isToday: true
        )

        var state = RebalanceFeature.State(accessToken: "token")
        state.availableDays = [day]
        state.selectedDayIDs = ["day-1"]
        state.preview = .init(proposed: [], summary: "Preview", changedCount: 1, unchangedCount: 0)
        state.isPreviewPresented = true
        state.errorMessage = "boom"
        state.isLoading = true
        state.isApplying = true

        let store = TestStore(initialState: state) {
            RebalanceFeature()
        }

        await store.send(.selectedDayToggled("day-1")) {
            $0.selectedDayIDs = []
            $0.isPreviewPresented = false
            $0.preview = nil
            $0.errorMessage = nil
        }

        await store.send(.previewTapped)
        #expect(store.state.isLoading)

        await store.send(.previewPresentationChanged(false))

        await store.send(.eventsFailed("Events failed")) {
            $0.errorMessage = "Events failed"
            $0.isLoading = false
            $0.isApplying = false
        }

        var proposeFailureState = store.state
        proposeFailureState.isLoading = true
        proposeFailureState.isApplying = true
        let proposeFailureStore = TestStore(initialState: proposeFailureState) {
            RebalanceFeature()
        }
        await proposeFailureStore.send(.proposeFailed("Propose failed")) {
            $0.errorMessage = "Propose failed"
            $0.isLoading = false
            $0.isApplying = false
        }

        var applyFailureState = proposeFailureStore.state
        applyFailureState.isLoading = true
        applyFailureState.isApplying = true
        let applyFailureStore = TestStore(initialState: applyFailureState) {
            RebalanceFeature()
        }
        await applyFailureStore.send(.applyFailed("Apply failed")) {
            $0.errorMessage = "Apply failed"
            $0.isLoading = false
            $0.isApplying = false
        }
    }

    @Test
    func dayBatteryLoadedMismatchedSignatureAndApplyCompletedBranchesBehave() async {
        let request = BatteryDayRequest(
            dayID: "day-1",
            endDate: Fixture.secondaryDate,
            entries: [],
            startDate: Fixture.referenceDate
        )
        let day = RebalanceFeature.State.DayItem(
            batteryRequest: request,
            id: "day-1",
            date: Fixture.referenceDate,
            eventCount: 0,
            isToday: true
        )

        var state = RebalanceFeature.State(accessToken: "token")
        state.availableDays = [day]
        state.activeDayBatteryID = "day-1"
        state.dayBatteryCache["day-1"] = .init(signature: "stale", state: .loading)
        state.isApplying = true

        let store = TestStore(initialState: state) {
            RebalanceFeature()
        } withDependencies: {
            $0.batteryClient.evaluate = { _, _ in .hidden }
            $0.batteryClient.evaluateDay = { _ in .hidden }
        }
        store.exhaustivity = .off

        await store.send(.dayBatteryLoaded("day-1", "fresh", .ready(80))) {
            $0.activeDayBatteryID = nil
        }
        #expect(store.state.dayBatteryCache["day-1"]?.state == .loading)

        await store.send(.applyTapped)
        #expect(store.state.isApplying)

        await store.send(.applyCompleted) {
            $0.isApplying = false
        }
        await store.receive(.delegate(.applied))
    }
}
