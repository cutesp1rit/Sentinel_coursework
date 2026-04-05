import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                    HomeTodaySnapshotSectionView(
                        snapshot: store.todaySnapshot
                    )

                    HomeEventsSectionView(
                        schedule: store.schedule
                    )

                    HomeCalendarSectionView(
                        dayStrip: store.dayStrip,
                        selectedDayID: store.selectedDayID,
                        onSelectDay: { store.send(.daySelected($0)) }
                    )

                    HomeBatterySectionView(
                        battery: store.battery
                    )

                    HomeQuickActionsSectionView(
                        onChatTap: { store.send(.chatTapped) },
                        onRebalanceTap: { store.send(.rebalanceTapped) }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.small)
                .padding(.bottom, AppSpacing.small)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.App.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.send(.profileTapped)
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel(L10n.Profile.openButton)
                }
            }
        }
        .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            store.send(.onAppear)
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
