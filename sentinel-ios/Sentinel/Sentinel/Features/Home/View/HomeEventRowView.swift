import SwiftUI

struct HomeEventRowView: View {
    let item: HomeScheduleItem

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(item.title)
                    .font(.body.weight(.semibold))

                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.medium)

            Text(item.timeText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
