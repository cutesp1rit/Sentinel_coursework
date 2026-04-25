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

    var categoryTitle: String {
        category.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var displayTitle: String {
        switch groupCode {
        case "events_created":
            return L10n.Achievements.eventsCreated
        case "ai_assisted":
            return L10n.Achievements.aiAssisted
        case "reminders":
            return L10n.Achievements.reminders
        case "active_days":
            return L10n.Achievements.activeDays
        default:
            return groupCode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var progressFraction: Double {
        guard let target = nextLockedLevel?.targetValue ?? levels.last?.targetValue, target > 0 else {
            return 1
        }
        return min(Double(currentValue) / Double(target), 1)
    }

    var progressCopy: String {
        if let nextLockedLevel {
            return L10n.Achievements.progressToLevel(currentValue, nextLockedLevel.targetValue)
        }
        return L10n.Achievements.completedGroup
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

    var levelTitle: String {
        L10n.Achievements.level(level)
    }

    var statusCopy: String {
        if unlocked {
            if let earnedAt {
                return L10n.Achievements.earnedAt(earnedAt.formatted(date: .abbreviated, time: .omitted))
            }
            return L10n.Achievements.unlocked
        }
        return L10n.Achievements.target(targetValue)
    }
}
