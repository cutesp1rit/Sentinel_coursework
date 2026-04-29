import SentinelUI
import SentinelCore
import SwiftUI

struct ChatHistoryPagingControlView: View {
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.small)
        } else {
            Button(L10n.ChatSheet.loadEarlierMessages, action: onTap)
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.small)
        }
    }
}
