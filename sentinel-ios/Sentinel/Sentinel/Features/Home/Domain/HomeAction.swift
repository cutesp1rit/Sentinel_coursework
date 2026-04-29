import ComposableArchitecture
import SentinelPlatformiOS
import SentinelCore
import Foundation

@CasePathable
enum HomeAction: Equatable {
    case achievements(AchievementsAction)
    case batteryRefreshRequested
    case batteryUpdated(HomeBatteryState)
    case achievementsFailed(String)
    case achievementsLoaded([AchievementGroup])
    case achievementsNavigationChanged(Bool)
    case achievementsTapped
    case calendar(CalendarAction)
    case calendarNavigationChanged(Bool)
    case chatTapped
    case createAccountTapped
    case daySelected(Int)
    case allEventsTapped
    case onAppear
    case profileTapped
    case rebalanceTapped
    case sessionChanged(AuthenticatedSession?)
    case signInTapped
    case scheduleLoadFailed(String)
    case scheduleLoaded(CalendarSyncClient.UpcomingSnapshot)
}
