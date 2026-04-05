import Foundation

struct AchievementsResponseDTO: Codable, Equatable {
    let groups: [AchievementGroupDTO]
}

struct AchievementGroupDTO: Codable, Equatable {
    let groupCode: String
    let category: String
    let counterName: String
    let currentValue: Int
    let levels: [AchievementLevelDTO]

    enum CodingKeys: String, CodingKey {
        case category
        case counterName = "counter_name"
        case currentValue = "current_value"
        case groupCode = "group_code"
        case levels
    }
}

struct AchievementLevelDTO: Codable, Equatable {
    let id: UUID
    let level: Int
    let title: String
    let description: String
    let icon: String
    let targetValue: Int
    let unlocked: Bool
    let earnedAt: Date?

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
