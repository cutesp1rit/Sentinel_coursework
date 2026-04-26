import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        appShell
    }

    private var appShell: some View {
        GeometryReader { proxy in
            HomeView(
                bottomOverlayInset: store.state.chatSheetInsetHeight(containerHeight: proxy.size.height),
                store: store.scope(state: \.home, action: \.home)
            )
            .task {
                await store.send(.task).finish()
            }
            #if os(iOS)
            .fullScreenCover(
                isPresented: Binding(
                    get: { store.isAuthFlowPresented },
                    set: { store.send(.authFlowPresentationChanged($0)) }
                ),
                onDismiss: { store.send(.authFlowDismissed) }
            ) {
                AuthFlowView(
                    onClose: { store.send(.authFlowPresentationChanged(false)) },
                    store: store.scope(state: \.auth, action: \.auth)
                )
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isProfileSheetPresented },
                    set: { store.send(.profileSheetPresentationChanged($0)) }
                ),
                onDismiss: { store.send(.profileSheetDismissed) }
            ) {
                ProfileSheetView(
                    onClose: { store.send(.profileSheetPresentationChanged(false)) },
                    store: store.scope(state: \.profile, action: \.profile)
                )
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isRebalanceSheetPresented },
                    set: { store.send(.rebalanceSheetPresentationChanged($0)) }
                ),
                onDismiss: { store.send(.rebalanceSheetDismissed) }
            ) {
                RebalanceSheetView(
                    onClose: { store.send(.rebalance(.delegate(.close))) },
                    store: store.scope(state: \.rebalance, action: \.rebalance)
                )
            }
            #endif
            .sheet(
                isPresented: Binding(
                    get: { store.isChatSheetPresented },
                    set: { store.send(.chatSheetPresentationChanged($0)) }
                ),
                onDismiss: { store.send(.chatSheetDismissed) }
            ) {
                ChatSheetView(
                    store: store.scope(state: \.chatSheet, action: \.chatSheet)
                )
                .interactiveDismissDisabled()
            }
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
