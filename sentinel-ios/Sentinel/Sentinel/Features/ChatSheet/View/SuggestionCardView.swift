import SwiftUI

struct SuggestionCardView: View {
    let suggestion: ChatSuggestion
    let isSelected: Bool
    let showsSelectionControl: Bool
    let isInteractive: Bool
    let onTap: () -> Void

    private var statusText: String? {
        switch suggestion.status {
        case .accepted:
            return L10n.ChatSheet.statusAccepted
        case .pending:
            return nil
        case .rejected:
            return L10n.ChatSheet.statusRejected
        }
    }

    private var statusTint: Color {
        switch suggestion.status {
        case .accepted:
            return .green
        case .pending:
            return .secondary
        case .rejected:
            return .secondary
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    RoundedRectangle(cornerRadius: AppSpacing.xSmall, style: .continuous)
                        .fill(suggestion.hasConflict ? .red : .blue)
                        .frame(
                            width: AppGrid.value(1),
                            height: AppGrid.value(10)
                        )

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(suggestion.timeRange)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(suggestion.location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AppSpacing.small) {
                        if let statusText {
                            Text(statusText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(statusTint)
                        }

                        if suggestion.hasConflict {
                            Label(L10n.ChatSheet.conflict, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.red)
                        }

                        if showsSelectionControl {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? .blue : .secondary)
                        }
                    }
                }
            }
            .padding(AppSpacing.large)
            .background(
                Color(uiColor: .secondarySystemFill),
                in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(
                        showsSelectionControl && isSelected ? Color.blue.opacity(AppOpacity.selection) : Color.clear,
                        lineWidth: AppStrokeWidth.emphasis
                    )
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isInteractive)
    }
}
