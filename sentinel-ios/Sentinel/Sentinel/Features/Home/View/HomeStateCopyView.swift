import SwiftUI

struct HomeStateCopyView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.body.weight(.semibold))

            Text(bodyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
