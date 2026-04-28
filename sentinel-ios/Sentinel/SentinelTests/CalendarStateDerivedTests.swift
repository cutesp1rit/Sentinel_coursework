import Foundation
import Testing
@testable import Sentinel

@MainActor
struct CalendarStateDerivedTests {
    @Test
    func editorPayloadTrimsFieldsAndHandlesEventKinds() {
        var editor = CalendarState.Editor()
        editor.title = "  Planning  "
        editor.description = "  Notes  "
        editor.location = "  Office  "
        editor.allDay = false
        editor.type = .event
        editor.isFixed = true

        let payload = editor.payload
        #expect(payload.title == "Planning")
        #expect(payload.description == "Notes")
        #expect(payload.location == "Office")
        #expect(payload.source == "user")
        #expect(payload.endAt == editor.endDate)

        editor.allDay = true
        #expect(editor.payload.endAt == nil)

        editor.allDay = false
        editor.type = .reminder
        #expect(editor.payload.endAt == nil)

        let existing = CalendarState.Editor(event: Fixture.event())
        #expect(existing.eventID == Fixture.eventID)
        #expect(existing.payload.source == nil)
    }

    @Test
    func agendaDerivedValuesBuildRowsSectionsAndConflicts() {
        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [
            Fixture.event(id: Fixture.eventID, title: "One", startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate),
            Fixture.event(id: Fixture.secondEventID, title: "Two", startAt: Fixture.referenceDate.addingTimeInterval(30 * 60), endAt: Fixture.tertiaryDate, type: .reminder)
        ]

        #expect(state.navigationTitle == L10n.Calendar.title)
        #expect(!state.selectedMonthLabel.isEmpty)
        #expect(state.weekStripDays.count == 7)
        #expect(state.selectedDayRows.count == 2)
        #expect(state.selectedDayRows.first?.conflictTitle == L10n.ChatSheet.conflict)
        #expect(state.selectedDayRows.last?.badge == L10n.Calendar.reminderTag)
        #expect(state.agendaSections.isEmpty == false)
        #expect(state.hasSection(for: Fixture.referenceDate))
        #expect(state.visibleSectionDate(for: [state.selectedSectionID: 10]) == Calendar.current.startOfDay(for: Fixture.referenceDate))
    }

    @Test
    func batteryRequestAndStatesUseAgendaSectionContext() throws {
        var state = CalendarState(accessToken: "token")
        state.selectedDate = Fixture.referenceDate
        state.events = [
            Fixture.event(id: Fixture.eventID, startAt: Fixture.referenceDate, endAt: Fixture.secondaryDate)
        ]

        let sectionID = state.selectedSectionID
        let request = try #require(state.batteryRequest(for: sectionID))
        #expect(request.dayID == sectionID)
        #expect(request.entries.count == 1)
        #expect(request.startDate <= request.endDate)
        #expect(state.dayBatteryState(for: sectionID) == .hidden)
        #expect(CalendarState.sectionID(for: Fixture.referenceDate) == sectionID)
        #expect(CalendarState.visibleRangeDates(for: Fixture.referenceDate).isEmpty == false)
    }

    @Test
    func timeTextCoversAllDayReminderAndTimedEvents() {
        let state = CalendarState(accessToken: "token")
        let allDay = Fixture.event(endAt: nil, allDay: true)
        #expect(state.timeText(for: allDay) == L10n.Calendar.allDay)

        let reminder = Fixture.event(endAt: nil, type: .reminder)
        #expect(state.timeText(for: reminder).isEmpty == false)

        let timed = Fixture.event(endAt: Fixture.secondaryDate)
        #expect(state.timeText(for: timed).contains("-"))
    }
}
