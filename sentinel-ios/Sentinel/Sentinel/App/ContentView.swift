import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AppFeature>

    init(
        store: StoreOf<AppFeature> = Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    ) {
        self.store = store
    }

    var body: some View {
        AppView(store: store)
    }
}

#Preview {
    ContentView()
}
