import SwiftUI

public struct PrimaryButton: View {
    public let title: String
    public let isEnabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(Color.black.opacity(isEnabled ? 0.82 : 0.24), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(isEnabled ? 1 : AppOpacity.disabled)
        .disabled(!isEnabled)
    }
}

public struct SecondaryTextAction: View {
    public let prompt: String?
    public let title: String
    public let action: () -> Void

    public init(
        _ title: String,
        prompt: String? = nil,
        action: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if let prompt {
                Text("\(prompt) \(title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

public struct ToolbarTextLabel: View {
    public let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .padding(.horizontal, AppSpacing.xSmall)
    }
}
