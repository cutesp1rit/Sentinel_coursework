import SwiftUI

struct AssistantAvatarView: View {
    var body: some View {
        Circle()
            .fill(Color(uiColor: .secondarySystemFill))
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
