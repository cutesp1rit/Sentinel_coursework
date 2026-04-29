import Foundation
import SentinelCore

enum AchievementsAction: Equatable {
    case achievementsFailed(String)
    case achievementsLoaded([AchievementGroup])
    case onAppear
    case retryTapped
}
