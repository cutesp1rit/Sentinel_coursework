import SentinelUI
import SentinelCore
import ComposableArchitecture
import SwiftUI

struct ChatSheetView: View {
    let store: StoreOf<ChatSheetReducer>

    var body: some View {
        NavigationStack {
            ZStack {
                if store.isChatListPresented {
                    ChatHistoryPickerView(
                        store: store.scope(state: \.list, action: \.list)
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    ChatThreadScreenView(
                        activeChatTitle: store.activeChatTitle,
                        detent: store.detent,
                        onDetentChanged: { store.send(.detentChanged($0)) },
                        onOpenChatList: { store.send(.chatListButtonTapped) },
                        store: store.scope(state: \.thread, action: \.thread)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.snappy(duration: AppAnimationDuration.standard), value: store.isChatListPresented)
            .background(AppPlatformColor.systemBackground)
            .onAppear {
                if store.detent == .collapsed {
                    store.send(.chatListPresentationChanged(false))
                }
                store.send(.sheetPresented)
            }
        }
        .presentationDetents([.chatCollapsed, .chatMedium, .large], selection: detentBinding)
        .presentationBackgroundInteraction(.enabled(upThrough: .chatMedium))
        .presentationContentInteraction(.scrolls)
        .presentationDragIndicator(.visible)
        .sentinelNavigationBarToolbarVisibility(store.detent == .collapsed && !store.isChatListPresented ? .hidden : .visible)
    }

    private var detentBinding: Binding<PresentationDetent> {
        Binding(
            get: { store.detent.presentationDetent },
            set: { store.send(.detentChanged(.init($0))) }
        )
    }
}
