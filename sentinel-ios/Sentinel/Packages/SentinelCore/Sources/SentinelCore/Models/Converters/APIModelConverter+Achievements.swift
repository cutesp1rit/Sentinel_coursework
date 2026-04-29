import Foundation

extension APIModelConverter {
    public nonisolated static func convert(_ dto: AchievementLevelDTO) -> AchievementLevel {
        AchievementLevel(
            id: dto.id,
            description: dto.description,
            earnedAt: dto.earnedAt,
            icon: dto.icon,
            level: dto.level,
            targetValue: dto.targetValue,
            title: dto.title,
            unlocked: dto.unlocked
        )
    }

    public nonisolated static func convert(_ dto: AchievementGroupDTO) -> AchievementGroup {
        AchievementGroup(
            id: dto.groupCode,
            category: dto.category,
            counterName: dto.counterName,
            currentValue: dto.currentValue,
            groupCode: dto.groupCode,
            levels: dto.levels.map(convert)
        )
    }
}
