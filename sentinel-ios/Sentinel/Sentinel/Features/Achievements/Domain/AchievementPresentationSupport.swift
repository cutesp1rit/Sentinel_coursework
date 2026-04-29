import SentinelCore
import Foundation

extension AchievementGroup {
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

    var progressCopy: String {
        if let nextLockedLevel {
            return L10n.Achievements.progressToLevel(currentValue, nextLockedLevel.targetValue)
        }
        return L10n.Achievements.completedGroup
    }
}

extension AchievementLevel {
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
