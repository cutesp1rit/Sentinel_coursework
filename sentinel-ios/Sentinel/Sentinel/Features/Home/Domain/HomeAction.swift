import Foundation

enum HomeAction: Equatable {
    case achievementsFailed(String)
    case achievementsLoaded([AchievementGroup])
    case chatTapped
    case daySelected(Int)
    case onAppear
    case profileTapped
    case rebalanceTapped
    case sessionChanged(AuthenticatedSession?)
    case scheduleLoadFailed(String)
    case scheduleLoaded(CalendarSyncClient.UpcomingSnapshot)
}
