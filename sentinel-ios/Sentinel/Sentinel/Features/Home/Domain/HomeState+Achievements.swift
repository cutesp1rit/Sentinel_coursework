import Foundation
import SentinelCore

extension HomeState {
    var nextAchievementHighlights: [HomeAchievementHighlight] {
        achievementGroups.compactMap { group in
            guard let nextLockedLevel = group.nextLockedLevel else { return nil }
            let groupTitle: String
            switch group.groupCode {
            case "events_created":
                groupTitle = L10n.Achievements.eventsCreated
            case "ai_assisted":
                groupTitle = L10n.Achievements.aiAssisted
            case "reminders":
                groupTitle = L10n.Achievements.reminders
            case "active_days":
                groupTitle = L10n.Achievements.activeDays
            default:
                groupTitle = group.groupCode.replacingOccurrences(of: "_", with: " ").capitalized
            }

            return HomeAchievementHighlight(
                id: nextLockedLevel.id,
                groupTitle: groupTitle,
                icon: nextLockedLevel.icon,
                progressFraction: min(Double(group.currentValue) / Double(max(nextLockedLevel.targetValue, 1)), 1),
                progressText: "\(group.currentValue)/\(nextLockedLevel.targetValue)",
                subtitle: groupTitle,
                title: nextLockedLevel.title
            )
        }
        .sorted { $0.progressFraction > $1.progressFraction }
    }

    var achievementPreviewHighlights: [HomeAchievementHighlight] {
        Array(nextAchievementHighlights.prefix(6))
    }
}
