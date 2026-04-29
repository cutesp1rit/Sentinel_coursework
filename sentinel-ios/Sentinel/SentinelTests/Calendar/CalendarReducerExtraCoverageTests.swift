import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct CalendarReducerExtraCoverageTests {
    @Test
    func calendarReducerGuardAndErrorBranchesStayStable() async {
        var loadingState = CalendarState(accessToken: "token")
        loadingState.isLoading = true
        let loadingStore = TestStore(initialState: loadingState) {
            CalendarReducer()
        }

        await loadingStore.send(.reloadRequested)
        await loadingStore.send(.saveTapped)
        await loadingStore.send(.dayBatteryRequested("missing"))

        var deleteState = CalendarState(accessToken: "token")
        deleteState.selectedDate = Fixture.referenceDate
        deleteState.isLoading = true
        let deleteStore = TestStore(initialState: deleteState) {
            CalendarReducer()
        }

        await deleteStore.send(.deleteFailed("Delete failed")) {
            $0.errorMessage = "Delete failed"
            $0.isLoading = false
        }

        var eventsState = deleteState
        let eventsStore = TestStore(initialState: eventsState) {
            CalendarReducer()
        }
        await eventsStore.send(.eventsFailed("Events failed")) {
            $0.errorMessage = "Events failed"
            $0.isLoading = false
        }

        var saveState = deleteState
        let saveStore = TestStore(initialState: saveState) {
            CalendarReducer()
        }
        await saveStore.send(.saveFailed("Save failed")) {
            $0.errorMessage = "Save failed"
            $0.isLoading = false
        }
    }

    @Test
    func calendarReducerDateAndBatteryBranchesCoverSameMonthAndCachedRequests() async {
        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)]
        let sectionID = state.selectedSectionID
        let request = state.batteryRequest(for: sectionID)!
        state.dayBatteryCache[sectionID] = .init(signature: request.signature, state: .ready(90))
        state.pendingScrollSectionID = "different"

        let store = TestStore(initialState: state) {
            CalendarReducer()
        }
        store.exhaustivity = .off

        await store.send(.dayBatteryRequested(sectionID))
        #expect(store.state.dayBatteryCache[sectionID]?.state == .ready(90))

        await store.send(.selectedDateChanged(Fixture.referenceDate.addingTimeInterval(60 * 60))) {
            $0.selectedDate = Fixture.referenceDate.addingTimeInterval(60 * 60)
            $0.isInlineMonthPickerVisible = false
            $0.pendingScrollSectionID = CalendarState.sectionID(for: Fixture.referenceDate.addingTimeInterval(60 * 60))
        }

        await store.send(.visibleDateChanged(Fixture.secondaryDate))
        #expect(store.state.pendingScrollSectionID == nil)
    }

    @Test
    func editorStartDateBranchPushesEndDateForwardWhenNeeded() async {
        var state = CalendarState(accessToken: "token")
        state.editor = .init()
        state.editor?.startDate = Fixture.referenceDate
        state.editor?.endDate = Fixture.referenceDate

        let store = TestStore(initialState: state) {
            CalendarReducer()
        }

        await store.send(.editorStartDateChanged(Fixture.secondaryDate)) {
            $0.editor?.startDate = Fixture.secondaryDate
            $0.editor?.endDate = Fixture.secondaryDate.addingTimeInterval(60 * 60)
        }
    }

    @Test
    func sameMonthSelectionAndDeleteSuccessBranchesBehave() async {
        let event = Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)
        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [event]

        let sameMonthStore = TestStore(initialState: state) {
            CalendarReducer()
        }
        await sameMonthStore.send(.selectedDateChanged(Fixture.referenceDate.addingTimeInterval(60 * 60))) {
            $0.selectedDate = Fixture.referenceDate.addingTimeInterval(60 * 60)
            $0.isInlineMonthPickerVisible = false
            $0.pendingScrollSectionID = CalendarState.sectionID(for: Fixture.referenceDate.addingTimeInterval(60 * 60))
        }

        let deleteStore = TestStore(initialState: state) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.deleteEvent = { id, token in
                #expect(id == Fixture.eventID)
                #expect(token == "token")
            }
            $0.eventsClient.listEvents = { _, _, _ in [] }
            $0.calendarSyncClient.sync = { request in
                #expect(request.deletedEventIDs == [Fixture.eventID])
                return .init()
            }
        }
        deleteStore.exhaustivity = .off

        await deleteStore.send(.deleteTapped(Fixture.eventID)) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await deleteStore.receive(.eventsLoaded([])) {
            $0.events = []
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
            $0.pendingScrollSectionID = $0.selectedSectionID
        }
    }
}
