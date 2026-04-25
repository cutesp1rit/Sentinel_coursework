import SwiftUI

struct HomeQuickActionsSectionView: View {
    let onChatTap: () -> Void
    let onRebalanceTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(L10n.Home.actionsTitle)
                .font(.headline)

            Button(action: onChatTap) {
                actionRow(
                    title: L10n.Home.chatTitle,
                    body: L10n.Home.chatBody,
                    systemImage: "message"
                )
            }
            .buttonStyle(.plain)

            Button(action: onRebalanceTap) {
                actionRow(
                    title: L10n.Home.rebalanceTitle,
                    body: L10n.Home.rebalanceBody,
                    systemImage: "arrow.triangle.2.circlepath"
                )
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(AppOpacity.disabled)
        }
    }

    private func actionRow(
        title: String,
        body: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: AppGrid.value(8), height: AppGrid.value(8))
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}
