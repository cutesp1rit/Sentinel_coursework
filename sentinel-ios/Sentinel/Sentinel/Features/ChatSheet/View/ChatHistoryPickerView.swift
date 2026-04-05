import SwiftUI

struct ChatHistoryPickerView: View {
    let chats: [ChatSheetState.ChatSummary]
    let activeChatID: UUID?
    let onCreateNewChat: () -> Void
    let onSelectChat: (UUID) -> Void

    var body: some View {
        List {
            Section {
                Button(action: onCreateNewChat) {
                    HStack(spacing: AppSpacing.medium) {
                        Label(L10n.ChatSheet.newChat, systemImage: "square.and.pencil")
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(chats) { chat in
                    Button {
                        onSelectChat(chat.id)
                    } label: {
                        HStack(spacing: AppSpacing.medium) {
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text(chat.title)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)

                                if let lastMessageAt = chat.lastMessageAt {
                                    Text(lastMessageAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if chat.id == activeChatID {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text(L10n.ChatSheet.historyTitle)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.ChatSheet.historyTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
