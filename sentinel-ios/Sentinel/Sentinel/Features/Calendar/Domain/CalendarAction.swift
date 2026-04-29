import Foundation
import SentinelCore

enum CalendarAction: Equatable {
    case addTapped
    case dayBatteryLoaded(String, String, DayBatteryBadgeState)
    case dayBatteryRequested(String)
    case deleteFailed(String)
    case deleteTapped(UUID)
    case editorAllDayChanged(Bool)
    case editorDescriptionChanged(String)
    case editorDismissed
    case editorEndDateChanged(Date)
    case editorFixedChanged(Bool)
    case editorLocationChanged(String)
    case editorStartDateChanged(Date)
    case editorTitleChanged(String)
    case editorTypeChanged(EventKind)
    case editTapped(UUID)
    case eventsFailed(String)
    case eventsLoaded([Event])
    case inlineMonthPickerVisibilityChanged(Bool)
    case onAppear
    case reloadRequested
    case saveFailed(String)
    case saveSucceeded
    case saveTapped
    case selectedDateChanged(Date)
    case visibleDateChanged(Date)
    case weekAdvanced(Int)
}
