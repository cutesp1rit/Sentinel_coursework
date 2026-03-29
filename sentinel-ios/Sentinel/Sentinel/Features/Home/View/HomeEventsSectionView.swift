import SwiftUI

struct HomeEventsSectionView: View {
    let schedule: HomeScheduleState

    var body: some View {
        HomeSectionCard(title: L10n.Home.eventsTitle) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if schedule.isLoading {
            HomeStateCopyView(
                title: L10n.Home.loadingTitle,
                bodyText: L10n.Home.loadingBody
            )
        } else if schedule.errorMessage != nil {
            HomeStateCopyView(
                title: L10n.Home.calendarErrorTitle,
                bodyText: L10n.Home.calendarErrorBody
            )
        } else {
            switch schedule.access {
            case .notRequested:
                HomeStateCopyView(
                    title: L10n.Home.connectCalendarTitle,
                    bodyText: L10n.Home.connectCalendarBody
                )

            case .denied:
                HomeStateCopyView(
                    title: L10n.Home.calendarDeniedTitle,
                    bodyText: L10n.Home.calendarDeniedBody
                )

            case .granted where schedule.upcomingItems.isEmpty:
                HomeStateCopyView(
                    title: L10n.Home.noEventsTitle,
                    bodyText: L10n.Home.noEventsBody
                )

            case .granted:
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    ForEach(schedule.upcomingItems) { item in
                        HomeEventRowView(item: item)
                    }
                }
            }
        }
    }
}
