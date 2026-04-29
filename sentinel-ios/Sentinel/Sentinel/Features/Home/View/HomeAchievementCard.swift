import SentinelUI
import SentinelCore
import SwiftUI

struct HomeAchievementCard: View {
    let highlight: HomeAchievementHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(highlight.icon)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(highlight.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                Text(highlight.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressView(value: highlight.progressFraction)
                .tint(.green)

            Text(highlight.progressText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 180, alignment: .leading)
        .padding(AppSpacing.large)
        .background(SentinelSurfaceCard())
    }
}
