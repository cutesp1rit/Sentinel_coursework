import ComposableArchitecture
import SwiftUI

struct ChatHistoryPickerView: View {
    let onBack: () -> Void
    let store: StoreOf<ChatListFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                header

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
        .overlay {
            if store.isLoading {
                ProgressView()
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.medium) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: AppGrid.value(11), height: AppGrid.value(11))
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(L10n.ChatSheet.chatsTitle)
                .font(.title3.weight(.bold))

            Spacer()

            Button(L10n.ChatSheet.newChat) {
                store.send(.newChatTapped)
                onBack()
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
        }
    }
}
