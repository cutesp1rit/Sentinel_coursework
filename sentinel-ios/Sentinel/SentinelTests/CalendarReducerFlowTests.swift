import SentinelUI
import SentinelPlatformiOS
import SentinelCore
import ComposableArchitecture
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct CalendarReducerFlowTests {
    @Test
    func addAndEditActionsManageEditorState() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.events = [Fixture.event()]

        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        }
        store.exhaustivity = .off

        await store.send(.addTapped)
        #expect(store.state.editor != nil)

        await store.send(.editorTitleChanged("Planning")) {
            $0.editor?.title = "Planning"
        }

        await store.send(.editorStartDateChanged(Fixture.secondaryDate)) {
            $0.editor?.startDate = Fixture.secondaryDate
        }

        await store.send(.editorDismissed) {
            $0.editor = nil
        }

        await store.send(.editTapped(Fixture.eventID)) {
            $0.editor = .init(event: Fixture.event())
        }
    }

    @Test
    func saveTappedWithBlankTitleShowsValidationError() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.editor = .init()
        initialState.editor?.title = "   "

        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        }

        await store.send(.saveTapped) {
            $0.errorMessage = L10n.Calendar.titleRequired
        }
    }

    @Test
    func onAppearAndReloadLoadEvents() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.selectedDate = Fixture.referenceDate

        let events = [Fixture.event()]
        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.listEvents = { _, _, token in
                #expect(token == "token")
                return events
            }
        }

        await store.send(.onAppear)
        await store.receive(.reloadRequested) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.eventsLoaded(events)) {
            $0.events = events
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
            $0.pendingScrollSectionID = $0.selectedSectionID
        }
    }

    @Test
    func selectedDateChangedAcrossMonthRequestsReload() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.selectedDate = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 31)) ?? Fixture.referenceDate

        let nextMonth = Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 1)) ?? Fixture.secondaryDate
        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.listEvents = { _, _, _ in [] }
        }

        await store.send(.selectedDateChanged(nextMonth)) {
            $0.selectedDate = nextMonth
            $0.isInlineMonthPickerVisible = false
            $0.pendingScrollSectionID = CalendarState.sectionID(for: nextMonth)
        }
        await store.receive(.reloadRequested) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await store.receive(.eventsLoaded([])) {
            $0.events = []
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
        }
    }

    @Test
    func dayBatteryFlowCachesAndLoadsState() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.selectedDate = Fixture.referenceDate
        initialState.events = [Fixture.event()]
        let sectionID = CalendarState.sectionID(for: Fixture.referenceDate)

        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        } withDependencies: {
            $0.batteryClient.evaluateDay = { _ in .ready(55) }
        }

        await store.send(.dayBatteryRequested(sectionID)) {
            let request = CalendarState(accessToken: "token", events: [Fixture.event()], selectedDate: Fixture.referenceDate).batteryRequest(for: sectionID)
            $0.dayBatteryCache[sectionID] = .init(signature: request?.signature ?? "", state: .loading)
            $0.activeDayBatterySectionID = sectionID
        }

        guard let signature = store.state.dayBatteryCache[sectionID]?.signature else {
            Issue.record("Expected cached battery signature")
            return
        }
        await store.receive(.dayBatteryLoaded(sectionID, signature, .ready(55))) {
            $0.dayBatteryCache[sectionID]?.state = .ready(55)
            $0.activeDayBatterySectionID = nil
        }
    }

    @Test
    func dayBatteryRequestQueuesWhenAnotherDayIsActive() async {
        var initialState = CalendarState(accessToken: "token")
        initialState.selectedDate = Fixture.referenceDate
        initialState.events = [
            Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate),
            Fixture.event(id: Fixture.secondEventID, startAt: Fixture.referenceDate.addingTimeInterval(24 * 60 * 60), endAt: Fixture.referenceDate.addingTimeInterval(25 * 60 * 60))
        ]
        let todayID = CalendarState.sectionID(for: Fixture.referenceDate)
        let tomorrowDate = Fixture.referenceDate.addingTimeInterval(24 * 60 * 60)
        let tomorrowID = CalendarState.sectionID(for: tomorrowDate)
        initialState.activeDayBatterySectionID = todayID

        let store = TestStore(initialState: initialState) {
            CalendarReducer()
        }

        await store.send(.dayBatteryRequested(tomorrowID)) {
            let request = CalendarState(accessToken: "token", events: initialState.events, selectedDate: Fixture.referenceDate).batteryRequest(for: tomorrowID)
            $0.dayBatteryCache[tomorrowID] = .init(signature: request?.signature ?? "", state: .loading)
            $0.queuedDayBatterySectionIDs = [tomorrowID]
        }
    }

    @Test
    func deleteAndSaveFailurePathsSetErrorMessage() async {
        var deleteState = CalendarState(accessToken: "token")
        deleteState.selectedDate = Fixture.referenceDate
        let deleteStore = TestStore(initialState: deleteState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.deleteEvent = { _, _ in
                throw APIError(code: "BAD", message: "Delete failed", details: nil)
            }
            $0.calendarSyncClient.sync = { _ in .init() }
        }

        await deleteStore.send(.deleteTapped(Fixture.eventID)) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await deleteStore.receive(.deleteFailed("Delete failed")) {
            $0.errorMessage = "Delete failed"
            $0.isLoading = false
        }

        var saveState = CalendarState(accessToken: "token")
        saveState.editor = .init()
        saveState.editor?.title = "Planning"
        let saveStore = TestStore(initialState: saveState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.createEvent = { _, _ in
                throw APIError(code: "BAD", message: "Save failed", details: nil)
            }
            $0.calendarSyncClient.sync = { _ in .init() }
        }

        await saveStore.send(.saveTapped) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await saveStore.receive(.saveFailed("Save failed")) {
            $0.errorMessage = "Save failed"
            $0.isLoading = false
        }
    }

    @Test
    func deleteAndSaveSuccessPathsRefreshEvents() async {
        let refreshed = [Fixture.event(id: Fixture.eventID, title: "Updated")]

        var deleteState = CalendarState(accessToken: "token")
        deleteState.selectedDate = Fixture.referenceDate
        deleteState.events = [Fixture.event()]
        let deleteStore = TestStore(initialState: deleteState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.deleteEvent = { _, _ in }
            $0.eventsClient.listEvents = { _, _, _ in refreshed }
            $0.calendarSyncClient.sync = { _ in .init(syncedEventIDs: [Fixture.eventID]) }
        }

        await deleteStore.send(.deleteTapped(Fixture.eventID)) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await deleteStore.receive(.eventsLoaded(refreshed)) {
            $0.events = refreshed
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
            $0.pendingScrollSectionID = $0.selectedSectionID
        }

        var saveState = CalendarState(accessToken: "token")
        saveState.selectedDate = Fixture.referenceDate
        saveState.editor = .init()
        saveState.editor?.title = "Planning"
        let saveStore = TestStore(initialState: saveState) {
            CalendarReducer()
        } withDependencies: {
            $0.eventsClient.createEvent = { _, _ in Fixture.event(id: Fixture.eventID, title: "Created") }
            $0.eventsClient.listEvents = { _, _, _ in refreshed }
            $0.calendarSyncClient.sync = { _ in .init(syncedEventIDs: [Fixture.eventID]) }
        }

        await saveStore.send(.saveTapped) {
            $0.errorMessage = nil
            $0.isLoading = true
        }
        await saveStore.receive(.eventsLoaded(refreshed)) {
            $0.events = refreshed
            $0.activeDayBatterySectionID = nil
            $0.queuedDayBatterySectionIDs = []
            $0.errorMessage = nil
            $0.isLoading = false
            $0.pendingScrollSectionID = $0.selectedSectionID
        }
        await saveStore.receive(.saveSucceeded) {
            $0.editor = nil
        }
    }
}
