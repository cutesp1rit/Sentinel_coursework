import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        HomeView(
            store: store.scope(state: \.home, action: \.home)
        )
        .sheet(isPresented: .constant(true)) {
            ChatSheetView(
                store: store.scope(state: \.chatSheet, action: \.chatSheet)
            )
            .interactiveDismissDisabled()
        }
    }
}

#Preview("App Shell") {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        }
    )
}
