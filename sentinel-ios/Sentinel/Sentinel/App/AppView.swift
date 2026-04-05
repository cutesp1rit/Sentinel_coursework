import ComposableArchitecture
import SwiftUI

struct AppView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        GeometryReader { proxy in
            HomeView(
                bottomOverlayInset: chatSheetInsetHeight(containerHeight: proxy.size.height),
                store: store.scope(state: \.home, action: \.home)
            )
            .task {
                await store.send(.task).finish()
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
                    store: store.scope(state: \.auth, action: \.auth)
                )
            }
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

    private func chatSheetInsetHeight(containerHeight: CGFloat) -> CGFloat {
        guard store.isChatSheetPresented else { return 0 }

        switch store.chatSheet.detent {
        case .collapsed:
            return AppGrid.value(24)
        case .medium:
            return max(containerHeight * 0.56, 420)
        case .large:
            return containerHeight * 0.82
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
