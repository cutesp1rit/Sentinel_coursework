import SwiftUI

public struct SheetHeader: View {
    public let title: String
    public let subtitle: String?
    public let trailingTitle: String?
    public let onTrailingTap: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        trailingTitle: String? = nil,
        onTrailingTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingTitle = trailingTitle
        self.onTrailingTap = onTrailingTap
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.title3.weight(.bold))

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let trailingTitle, let onTrailingTap {
                Button(trailingTitle, action: onTrailingTap)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }
}

public struct SettingsSectionCard<Content: View>: View {
    public let title: String
    public let footer: String?
    @ViewBuilder let content: Content

    public init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppPlatformColor.secondaryGroupedBackground.opacity(0.86))
            )

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.large)
        .background(SentinelCardBackground(cornerRadius: 30))
    }
}

public struct SettingsRow<Accessory: View>: View {
    public let systemImage: String
    public let title: String
    public let tint: Color
    public let accessory: Accessory
    public let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        tint: Color = .primary,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.systemImage = systemImage
        self.title = title
        self.tint = tint
        self.action = action
        self.accessory = accessory()
    }

    public var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                accessory
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
        }
        .buttonStyle(.plain)
    }
}

public struct AccountActionRow: View {
    public let title: String
    public let systemImage: String
    public let role: ButtonRole?
    public let tint: Color
    public let action: () -> Void

    public init(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        tint: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: AppSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 28)
                    .foregroundStyle(tint)

                Text(title)
                    .font(.body)
                    .foregroundStyle(tint)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
        }
        .buttonStyle(.plain)
    }
}
