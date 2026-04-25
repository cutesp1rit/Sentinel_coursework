import ComposableArchitecture
import SwiftUI

struct ChatSheetView: View {
    private enum Route: Hashable {
        case chats
    }

    let store: StoreOf<ChatSheetReducer>
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ChatThreadScreenView(
                activeChatTitle: store.activeChatTitle,
                detent: store.detent,
                onDetentChanged: { store.send(.detentChanged($0)) },
                onOpenChatList: { store.send(.chatListButtonTapped) },
                store: store.scope(state: \.thread, action: \.thread)
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .chats:
                    ChatHistoryPickerView(
                        store: store.scope(state: \.list, action: \.list)
                    )
                }
            }
            .onAppear {
                syncPath(animated: false)
            }
            .onChange(of: store.isChatListPresented) { _, _ in
                syncPath(animated: true)
            }
        }
    }

    private func syncPath(animated: Bool) {
        let targetPath: [Route] = store.isChatListPresented ? [.chats] : []
        guard targetPath != path else { return }
        if animated {
            withAnimation(.snappy(duration: AppAnimationDuration.standard)) {
                path = targetPath
            }
        } else {
            path = targetPath
        }
    }
}
