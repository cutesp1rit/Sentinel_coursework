import SentinelUI
import SentinelCore
import SwiftUI

struct AssistantAvatarView: View {
    var body: some View {
        Circle()
            .fill(AppPlatformColor.tertiaryGroupedBackground)
            .frame(
                width: AppGrid.value(7),
                height: AppGrid.value(7)
            )
            .overlay {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
    }
}
