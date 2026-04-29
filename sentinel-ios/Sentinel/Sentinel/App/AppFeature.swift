import SentinelUI
import SentinelCore
import ComposableArchitecture

@Reducer
struct AppFeature: Reducer {
    var body: some Reducer<State, Action> {
        CombineReducers {
            Scope(state: \.auth, action: \.auth) {
                AuthReducer()
            }

            Scope(state: \.home, action: \.home) {
                HomeReducer()
            }

            Scope(state: \.chatSheet, action: \.chatSheet) {
                ChatSheetReducer()
            }

            Scope(state: \.profile, action: \.profile) {
                ProfileFeature()
            }

            Scope(state: \.rebalance, action: \.rebalance) {
                RebalanceFeature()
            }

            Coordinator()
        }
    }
}
