import SentinelUI
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct CalendarReducerBranchCoverageTests {
    @Test
    func editorMutationsAddEditDismissAndSaveSuccessBranchesWork() async {
        var state = CalendarState(accessToken: "token")
        state.events = [Fixture.event(id: Fixture.eventID, title: "Planning")]

        let store = TestStore(initialState: state) {
            CalendarReducer()
        }
        store.exhaustivity = .off

        await store.send(.addTapped)
        #expect(store.state.editor != nil)

        let start = Fixture.referenceDate
        await store.send(.editorStartDateChanged(start)) {
            $0.editor?.startDate = start
        }
        await store.send(.editorEndDateChanged(Fixture.secondaryDate)) {
            $0.editor?.endDate = Fixture.secondaryDate
        }
        await store.send(.editorTitleChanged("Review")) {
            $0.editor?.title = "Review"
        }
        await store.send(.editorDescriptionChanged("Desc")) {
            $0.editor?.description = "Desc"
        }
        await store.send(.editorLocationChanged("Office")) {
            $0.editor?.location = "Office"
        }
        await store.send(.editorFixedChanged(true)) {
            $0.editor?.isFixed = true
        }
        await store.send(.editorAllDayChanged(true)) {
            $0.editor?.allDay = true
        }
        await store.send(.editorTypeChanged(.reminder)) {
            $0.editor?.type = .reminder
        }
        await store.send(.editorDismissed) {
            $0.editor = nil
        }

        await store.send(.editTapped(Fixture.eventID)) {
            $0.editor = .init(event: Fixture.event(id: Fixture.eventID, title: "Planning"))
        }
        await store.send(.saveSucceeded) {
            $0.editor = nil
        }

        await store.send(.editTapped(UUID()))
        #expect(store.state.editor == nil)
    }

    @Test
    func calendarLoadingAndSelectionBranchesCoverNoopsAndPendingScrollLogic() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.selectedDate = Fixture.referenceDate
        initialState.isInlineMonthPickerVisible = true
        initialState.pendingScrollSectionID = "later"
        initialState.events = [Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)]

        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.listEvents = { _, _, _ in
                [Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)]
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.send(.reloadRequested) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.eventsLoaded([Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)])) {
            $0.events = [Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)]
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
        }

        await store.send(.visibleDateChanged(Fixture.referenceDate))
        #expect(store.state.pendingScrollSectionID == "later")

        let matchingID = CalendarState.sectionID(for: Fixture.referenceDate)
        var matchingState = store.state
        matchingState.pendingScrollSectionID = matchingID
        let matchingStore = TestStore(initialState: matchingState) {
            CalendarReducer()
        }
        await matchingStore.send(.visibleDateChanged(Fixture.referenceDate)) {
            $0.pendingScrollSectionID = nil
            $0.selectedDate = Fixture.referenceDate
        }

        await store.send(.inlineMonthPickerVisibilityChanged(false)) {
            $0.isInlineMonthPickerVisible = false
        }

        await store.send(.selectedDateChanged(Fixture.secondaryDate)) {
            $0.selectedDate = Fixture.secondaryDate
            $0.isInlineMonthPickerVisible = false
            $0.pendingScrollSectionID = CalendarState.sectionID(for: Fixture.secondaryDate)
        }

        await store.send(.weekAdvanced(1)) {
            $0.selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: Fixture.secondaryDate) ?? Fixture.secondaryDate
            $0.pendingScrollSectionID = $0.selectedSectionID
        }
        await store.receive(.reloadRequested) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
    }
}
