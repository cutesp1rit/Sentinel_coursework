import SwiftUI

struct HomeBatterySectionView: View {
    let battery: HomeBatteryState

    var body: some View {
        HomeSectionCard(title: L10n.Home.batteryTitle) {
            HomeStateCopyView(
                title: battery.displaySnapshot.headline,
                bodyText: battery.displaySnapshot.detail
            )
        }
    }
}
