import SwiftUI

struct HomeHeaderView: View {
    let dateText: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(L10n.App.title)
                    .font(.largeTitle.bold())

                Text(dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(L10n.Home.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(L10n.Home.localStatus)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
                .background(AppPlatformColor.secondaryGroupedBackground)
                .clipShape(Capsule())
        }
    }
}
