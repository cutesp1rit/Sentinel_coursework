import Foundation

public struct AchievementGroup: Equatable, Identifiable, Sendable {
    public let id: String
    public let category: String
    public let counterName: String
    public let currentValue: Int
    public let groupCode: String
    public let levels: [AchievementLevel]

    public var highestUnlockedLevel: Int? {
        levels.last(where: \.unlocked)?.level
    }

    public var nextLockedLevel: AchievementLevel? {
        levels.first(where: { !$0.unlocked })
    }

    public var categoryTitle: String {
        category.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var progressFraction: Double {
        guard let target = nextLockedLevel?.targetValue ?? levels.last?.targetValue, target > 0 else {
            return 1
        }
        return min(Double(currentValue) / Double(target), 1)
    }

    public init(
        id: String,
        category: String,
        counterName: String,
        currentValue: Int,
        groupCode: String,
        levels: [AchievementLevel]
    ) {
        self.id = id
        self.category = category
        self.counterName = counterName
        self.currentValue = currentValue
        self.groupCode = groupCode
        self.levels = levels
    }
}

public struct AchievementLevel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let description: String
    public let earnedAt: Date?
    public let icon: String
    public let level: Int
    public let targetValue: Int
    public let title: String
    public let unlocked: Bool

    public init(
        id: UUID,
        description: String,
        earnedAt: Date?,
        icon: String,
        level: Int,
        targetValue: Int,
        title: String,
        unlocked: Bool
    ) {
        self.id = id
        self.description = description
        self.earnedAt = earnedAt
        self.icon = icon
        self.level = level
        self.targetValue = targetValue
        self.title = title
        self.unlocked = unlocked
    }
}
