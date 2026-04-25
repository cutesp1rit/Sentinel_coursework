import SwiftUI

struct ChatHistoryPickerView: View {
    let chats: [ChatSheetState.ChatSummary]
    let activeChatID: UUID?
    let onCreateNewChat: () -> Void
    let onDeleteChat: (UUID) -> Void
    let onSelectChat: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(chats) { chat in
                    ChatListRow(
                        title: chat.title,
                        subtitle: subtitle(for: chat),
                        state: chat.id == activeChatID ? .selected : .regular
                    ) {
                        onSelectChat(chat.id)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            onDeleteChat(chat.id)
                        } label: {
                            Label(L10n.ChatSheet.deleteChat, systemImage: "trash")
                        }
                    }
                }

                if chats.isEmpty {
                    EmptyStateCard(
                        title: L10n.ChatSheet.noChatsTitle,
                        bodyText: L10n.ChatSheet.noChatsBody
                    )
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.large)
        }
        .background(HomeTopGradientBackground().ignoresSafeArea())
        .navigationTitle(L10n.ChatSheet.chatsTitle)
        .sentinelInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: sentinelToolbarTrailingPlacement) {
                Button(L10n.ChatSheet.newChat, action: onCreateNewChat)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func subtitle(for chat: ChatSheetState.ChatSummary) -> String? {
        guard let lastMessageAt = chat.lastMessageAt else { return nil }
        return lastMessageAt.formatted(date: .abbreviated, time: .shortened)
    }
}
