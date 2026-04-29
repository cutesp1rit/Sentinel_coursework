import SentinelUI
import SentinelCore
import SwiftUI

struct AuthStatusBanner: View {
    let message: String
    let tint: Color
    let foreground: Color

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(foreground)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
