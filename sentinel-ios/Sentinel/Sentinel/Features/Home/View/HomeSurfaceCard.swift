import SentinelUI
import SentinelCore
import SwiftUI

struct SentinelSurfaceCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(AppPlatformColor.systemBackground)
    }
}
