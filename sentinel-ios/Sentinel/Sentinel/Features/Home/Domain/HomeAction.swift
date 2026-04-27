import Foundation

enum HomeAction: Equatable {
    case batteryRefreshRequested
    case batteryUpdated(HomeBatteryState)
    case achievementsFailed(String)
    case achievementsLoaded([AchievementGroup])
    case chatTapped
    case createAccountTapped
    case daySelected(Int)
    case onAppear
    case profileTapped
    case rebalanceTapped
    case sessionChanged(AuthenticatedSession?)
    case signInTapped
    case scheduleLoadFailed(String)
    case scheduleLoaded(CalendarSyncClient.UpcomingSnapshot)
}
