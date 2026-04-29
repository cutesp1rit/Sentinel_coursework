import SwiftUI
import SentinelCore

struct HomeTodaySnapshotSectionView: View {
    let snapshot: HomeSnapshot

    var body: some View {
        HomeSectionCard(title: L10n.Home.todaySnapshotTitle) {
            HomeStateCopyView(
                title: snapshot.title,
                bodyText: snapshot.detail
            )
        }
    }
}
