import Foundation

struct HomeState: Equatable {
    var schedule = HomeScheduleState()
    var battery = HomeBatteryState.placeholder
    var dayStrip = HomeDayMarker.previewWeek
    var selectedDayID = 0

    var todaySnapshot: HomeSnapshot {
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
