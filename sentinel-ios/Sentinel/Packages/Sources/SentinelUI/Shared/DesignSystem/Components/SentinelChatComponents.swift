import SwiftUI

public enum SelectedChatListRowState: Equatable {
    case selected
    case regular
}

public struct ChatListRow: View {
    public let title: String
    public let subtitle: String?
    public let state: SelectedChatListRowState
    public let action: () -> Void

    public init(
        title: String,
        subtitle: String?,
        state: SelectedChatListRowState,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small + 2)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var rowBackground: some View {
        switch state {
        case .selected:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPlatformColor.secondaryGroupedBackground)
        case .regular:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
        }
    }
}
