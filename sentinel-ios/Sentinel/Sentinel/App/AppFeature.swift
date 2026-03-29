import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {
        var home = HomeState()
    }

    @CasePathable
    enum Action: Equatable {
        case home(HomeAction)
    }

    var body: some Reducer<State, Action> {
        Scope(state: \.home, action: \.home) {
            HomeReducer()
        }
    }
}
