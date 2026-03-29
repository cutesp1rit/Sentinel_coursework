import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: Store<HomeState, HomeAction>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        HomeHeaderView()

                        HomeTodaySnapshotSectionView(
                            snapshot: viewStore.todaySnapshot
                        )

                        HomeEventsSectionView(
                            schedule: viewStore.schedule
                        )

                        HomeCalendarSectionView(
                            dayStrip: viewStore.dayStrip,
                            selectedDayID: viewStore.selectedDayID,
                            onSelectDay: { viewStore.send(.daySelected($0)) }
                        )

                        HomeBatterySectionView(
                            battery: viewStore.battery
                        )

                        HomeQuickActionsSectionView(
                            onChatTap: { viewStore.send(.chatTapped) },
                            onRebalanceTap: { viewStore.send(.rebalanceTapped) }
                        )
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.vertical, AppSpacing.xLarge)
                }
                .background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(L10n.App.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeState()) {
            HomeReducer()
        }
    )
}
