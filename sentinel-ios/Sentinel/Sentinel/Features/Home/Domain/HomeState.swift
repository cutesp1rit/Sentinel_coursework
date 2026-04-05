import ComposableArchitecture
import Foundation

@ObservableState
struct HomeState: Equatable {
    var accessToken: String?
    var achievementGroups: [AchievementGroup] = []
    var schedule = HomeScheduleState()
    var battery = HomeBatteryState.placeholder
    var dayStrip = HomeDayMarker.previewWeek
    var selectedDayID = 0
    var userEmail: String?

    var allEventSections: [HomeEventDaySection] {
        let grouped = Dictionary(grouping: schedule.upcomingItems) { item in
            Calendar.current.startOfDay(for: item.startDate)
        }

        return grouped.keys.sorted().map { day in
            HomeEventDaySection(
                id: day.formatted(.iso8601.year().month().day()),
                date: day,
                items: grouped[day, default: []].sorted { $0.startDate < $1.startDate }
            )
        }
    }

    var displayName: String {
        guard let userEmail, !userEmail.isEmpty else {
            return "Sentinel"
        }

        let localPart = userEmail.split(separator: "@").first.map(String.init) ?? userEmail
        return localPart
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    var isAuthenticated: Bool {
        accessToken != nil
    }

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

    var resourceBatteryProgress: Double {
        switch battery {
        case .placeholder:
            return 0.5
        case .unavailable:
            return 0.0
        case let .ready(snapshot):
            let digits = snapshot.headline.filter(\.isNumber)
            if let value = Double(digits) {
                return min(max(value / 100, 0), 1)
            }
            return 0.67
        }
    }

    var resourceBatteryTitle: String {
        switch battery {
        case .placeholder:
            return "Resource"
        case .unavailable:
            return "Unavailable"
        case let .ready(snapshot):
            return snapshot.headline
        }
    }

    var scheduleMetricDetail: String {
        if let firstItem = todayPreviewItems.first {
            return "Next: \(firstItem.timeText)"
        }
        return L10n.Home.emptyTodayBody
    }

    var scheduleMetricValue: String {
        todayPreviewItems.isEmpty ? L10n.Home.metricFreeValue : L10n.Home.metricNextValue
    }

    var todayItems: [HomeScheduleItem] {
        let calendar = Calendar.current
        return schedule.upcomingItems
            .filter { calendar.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var todayPreviewItems: [HomeScheduleItem] {
        Array(todayItems.prefix(3))
    }

    var todayTitle: String {
        let count = todayItems.count
        if count == 0 {
            return L10n.Home.noEventsToday
        }
        return L10n.Home.todayCount(count)
    }

    var todaySnapshot: HomeSnapshot {
        guard isAuthenticated else {
            return HomeSnapshot(
                title: L10n.Home.signedOutHeroTitle,
                detail: L10n.Home.signedOutHeroBody
            )
        }

        if schedule.isLoading {
            return HomeSnapshot(
                title: L10n.Home.loadingTitle,
                detail: L10n.Home.loadingBody
            )
        }

        if schedule.errorMessage != nil {
            return HomeSnapshot(
                title: L10n.Home.calendarErrorTitle,
                detail: L10n.Home.calendarErrorBody
            )
        }

        switch schedule.access {
        case .notRequested:
            return HomeSnapshot(
                title: L10n.Home.noEventsToday,
                detail: L10n.Home.todaySummaryBody
            )

        case .denied:
            return HomeSnapshot(
                title: L10n.Home.calendarDeniedTitle,
                detail: L10n.Home.calendarDeniedBody
            )

        case .granted:
            guard let firstItem = schedule.upcomingItems.first else {
                return HomeSnapshot(
                    title: L10n.Home.noEventsToday,
                    detail: L10n.Home.noEventsTodayBody
                )
            }

            return HomeSnapshot(
                title: "\(schedule.upcomingItems.count) events planned",
                detail: "Next: \(firstItem.title) at \(firstItem.timeText)."
            )
        }
    }
}
