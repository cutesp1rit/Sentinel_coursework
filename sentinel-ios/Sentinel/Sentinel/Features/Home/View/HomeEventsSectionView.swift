import SentinelUI
import SentinelCore
import SwiftUI

struct HomeEventsSectionView: View {
    let schedule: HomeScheduleState

    var body: some View {
        HomeSectionCard(title: L10n.Home.eventsTitle) {
            if schedule.access == .granted && !schedule.upcomingItems.isEmpty && !schedule.isLoading && schedule.errorMessage == nil {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    ForEach(schedule.upcomingItems) { item in
                        HomeEventRowView(item: item)
                    }
                }
            } else {
                HomeStateCopyView(
                    title: schedule.emptyStateCopy.title,
                    bodyText: schedule.emptyStateCopy.detail
                )
            }
        }
    }
}
