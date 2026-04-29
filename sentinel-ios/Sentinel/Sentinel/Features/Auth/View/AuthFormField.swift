import SentinelUI
import SentinelCore
import SwiftUI

struct AuthFormField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content
                .padding(.horizontal, AppSpacing.large)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppPlatformColor.secondaryGroupedBackground.opacity(0.84))
                )
        }
    }
}
