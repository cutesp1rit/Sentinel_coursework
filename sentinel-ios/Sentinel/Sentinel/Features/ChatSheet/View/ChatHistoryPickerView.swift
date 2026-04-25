import ComposableArchitecture
import SwiftUI

struct ChatHistoryPickerView: View {
    let store: StoreOf<ChatListFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                if let errorMessage = store.errorMessage {
                    EmptyStateCard(title: L10n.ChatSheet.errorTitle, bodyText: errorMessage)
                }

                ForEach(store.chats) { chat in
                    ChatListRow(
                        title: chat.title,
                        subtitle: chat.subtitle,
                        state: chat.id == store.activeChatID ? .selected : .regular
                    ) {
                        store.send(.rowTapped(chat.id))
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.send(.chatDeleteRequested(chat.id))
                        } label: {
                            Label(L10n.ChatSheet.deleteChat, systemImage: "trash")
                        }
                    }
                }

                if store.chats.isEmpty && !store.isLoading {
                    EmptyStateCard(
                        title: L10n.ChatSheet.noChatsTitle,
                        bodyText: L10n.ChatSheet.noChatsBody
                    )
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
        }
        .background(AppPlatformColor.systemGroupedBackground.ignoresSafeArea())
        .navigationTitle(L10n.ChatSheet.chatsTitle)
        .sentinelInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                Button(L10n.ChatSheet.newChat) {
                    store.send(.newChatTapped)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .task {
            store.send(.onAppear)
        }
    }
}
