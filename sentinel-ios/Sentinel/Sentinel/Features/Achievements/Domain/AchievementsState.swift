import ComposableArchitecture
import SentinelCore
import Foundation

@ObservableState
struct AchievementsState: Equatable {
    let accessToken: String
    var errorMessage: String?
    var groups: [AchievementGroup] = []
    var hasLoaded = false
    var isLoading = false

    var totalUnlockedCount: Int {
        groups.flatMap(\.levels).filter(\.unlocked).count
    }

    var totalLevelCount: Int {
        groups.flatMap(\.levels).count
    }
}
