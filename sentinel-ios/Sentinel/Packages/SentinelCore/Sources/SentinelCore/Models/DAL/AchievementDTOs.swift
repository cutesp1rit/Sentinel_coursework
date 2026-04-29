import Foundation

public struct AchievementsResponseDTO: Codable, Equatable, Sendable {
    public let groups: [AchievementGroupDTO]

    public init(groups: [AchievementGroupDTO]) {
        self.groups = groups
    }
}

public struct AchievementGroupDTO: Codable, Equatable, Sendable {
    public let groupCode: String
    public let category: String
    public let counterName: String
    public let currentValue: Int
    public let levels: [AchievementLevelDTO]

    public init(
        groupCode: String,
        category: String,
        counterName: String,
        currentValue: Int,
        levels: [AchievementLevelDTO]
    ) {
        self.groupCode = groupCode
        self.category = category
        self.counterName = counterName
        self.currentValue = currentValue
        self.levels = levels
    }

    enum CodingKeys: String, CodingKey {
        case category
        case counterName = "counter_name"
        case currentValue = "current_value"
        case groupCode = "group_code"
        case levels
    }
}

public struct AchievementLevelDTO: Codable, Equatable, Sendable {
    public let id: UUID
    public let level: Int
    public let title: String
    public let description: String
    public let icon: String
    public let targetValue: Int
    public let unlocked: Bool
    public let earnedAt: Date?

    public init(
        id: UUID,
        level: Int,
        title: String,
        description: String,
        icon: String,
        targetValue: Int,
        unlocked: Bool,
        earnedAt: Date?
    ) {
        self.id = id
        self.level = level
        self.title = title
        self.description = description
        self.icon = icon
        self.targetValue = targetValue
        self.unlocked = unlocked
        self.earnedAt = earnedAt
    }

    enum CodingKeys: String, CodingKey {
        case description
        case earnedAt = "earned_at"
        case icon
        case id
        case level
        case targetValue = "target_value"
        case title
        case unlocked
    }
}
