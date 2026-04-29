import SwiftUI
import SentinelCore

extension HomeState {
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

    var scheduleMetricCard: MetricCardModel {
        if let nextItem = schedule.upcomingItems.first {
            return MetricCardModel(
                detail: "\(nextItem.timeText) • \(todayTitle)",
                systemImage: "calendar.badge.clock",
                tint: .primary,
                title: L10n.Home.metricTodayTitle,
                value: nextItem.title
            )
        }

        return MetricCardModel(
            detail: L10n.Home.emptyTodayBody,
            systemImage: "calendar",
            tint: .primary,
            title: L10n.Home.metricTodayTitle,
            value: L10n.Home.noEventsToday
        )
    }
}
