import Foundation

struct AchievementGroup: Equatable, Identifiable, Sendable {
    let id: String
    let category: String
    let counterName: String
    let currentValue: Int
    let groupCode: String
    let levels: [AchievementLevel]

    var highestUnlockedLevel: Int? {
        levels.last(where: \.unlocked)?.level
    }

    var nextLockedLevel: AchievementLevel? {
        levels.first(where: { !$0.unlocked })
    }
}

struct AchievementLevel: Equatable, Identifiable, Sendable {
    let id: UUID
    let description: String
    let earnedAt: Date?
    let icon: String
    let level: Int
    let targetValue: Int
    let title: String
    let unlocked: Bool
}
