import SentinelUI
import SentinelCore
import Foundation
import Testing
@testable import Sentinel

@MainActor
struct CalendarStateExtraCoverageTests {
    @Test
    func calendarStateNestedTypesExposeTitlesAndDefaultInitialization() {
        let section = CalendarState.AgendaSection(
            id: "day",
            date: Fixture.referenceDate,
            rows: []
        )
        #expect(section.title.isEmpty == false)
        #expect(section.subtitle.isEmpty == false)

        let editor = CalendarState.Editor(event: nil)
        #expect(editor.title.isEmpty)
        #expect(editor.location.isEmpty)
        #expect(editor.type == .event)
        #expect(editor.endDate > editor.startDate)
    }
}
