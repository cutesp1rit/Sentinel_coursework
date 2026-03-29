import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {
        var home = HomeState()
        var chatSheet = ChatSheetState.initial
    }

    @CasePathable
    enum Action: Equatable {
        case home(HomeAction)
        case chatSheet(ChatSheetAction)
    }

    var body: some Reducer<State, Action> {
        CombineReducers {
            Scope(state: \.home, action: \.home) {
                HomeReducer()
            }

            Scope(state: \.chatSheet, action: \.chatSheet) {
                ChatSheetReducer()
            }
        }
    }
}
