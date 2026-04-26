import ComposableArchitecture
import SwiftUI

struct ChatSheetView: View {
    let store: StoreOf<ChatSheetReducer>

    var body: some View {
        ZStack {
            if store.isChatListPresented {
                ChatHistoryPickerView(
                    onBack: { store.send(.chatListPresentationChanged(false)) },
                    store: store.scope(state: \.list, action: \.list)
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                NavigationStack {
                    ChatThreadScreenView(
                        activeChatTitle: store.activeChatTitle,
                        detent: store.detent,
                        onDetentChanged: { store.send(.detentChanged($0)) },
                        onOpenChatList: { store.send(.chatListButtonTapped) },
                        store: store.scope(state: \.thread, action: \.thread)
                    )
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: AppAnimationDuration.standard), value: store.isChatListPresented)
        .background(AppPlatformColor.systemBackground)
        .onAppear {
            if store.detent == .collapsed {
                store.send(.chatListPresentationChanged(false))
            }
        }
    }
}
