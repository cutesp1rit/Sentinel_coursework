import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {}

    enum Action {}

    var body: some Reducer<State, Action> {
        Reduce { _, _ in
            .none
        }
    }
}
