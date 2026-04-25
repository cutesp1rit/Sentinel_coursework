import Foundation

enum CalendarAction: Equatable {
    case addTapped
    case anchorDateChanged(Date)
    case anchorDateAdvanced(Int)
    case deleteFailed(String)
    case deleteTapped(UUID)
    case displayModeChanged(CalendarState.DisplayMode)
    case editorAllDayChanged(Bool)
    case editorDescriptionChanged(String)
    case editorDismissed
    case editorEndDateChanged(Date)
    case editorLocationChanged(String)
    case editorStartDateChanged(Date)
    case editorTitleChanged(String)
    case editorTypeChanged(EventKind)
    case editTapped(UUID)
    case eventsFailed(String)
    case eventsLoaded([Event])
    case onAppear
    case reloadRequested
    case saveFailed(String)
    case saveSucceeded
    case saveTapped
}
