import SwiftUI

struct SuggestionCardView: View {
    let suggestion: ChatSheetState.Suggestion
    let isSelected: Bool
    let showsSelectionControl: Bool
    let isInteractive: Bool
    let onTap: () -> Void

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
