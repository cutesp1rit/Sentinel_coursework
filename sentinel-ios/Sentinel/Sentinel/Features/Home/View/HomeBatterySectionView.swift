import SwiftUI

struct HomeBatterySectionView: View {
    let battery: HomeBatteryState

    var body: some View {
        HomeSectionCard(title: L10n.Home.batteryTitle) {
            switch battery {
            case .placeholder:
                HomeStateCopyView(
                    title: L10n.Home.batteryPlaceholderTitle,
                    bodyText: L10n.Home.batteryPlaceholderBody
                )

            case .unavailable:
                HomeStateCopyView(
                    title: L10n.Home.batteryUnavailableTitle,
                    bodyText: L10n.Home.batteryUnavailableBody
                )

            case let .ready(snapshot):
                HomeStateCopyView(
                    title: snapshot.headline,
                    bodyText: snapshot.detail
                )
            }
        }
    }
}
