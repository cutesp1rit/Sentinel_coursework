import ComposableArchitecture

struct HomeReducer: Reducer {
    typealias State = HomeState
    typealias Action = HomeAction

    var body: some Reducer<HomeState, HomeAction> {
        Reduce { state, action in
            switch action {
            case .chatTapped, .profileTapped, .rebalanceTapped:
                return .none

            case let .daySelected(dayID):
                state.selectedDayID = dayID
                return .none
            }
        }
    }
}
