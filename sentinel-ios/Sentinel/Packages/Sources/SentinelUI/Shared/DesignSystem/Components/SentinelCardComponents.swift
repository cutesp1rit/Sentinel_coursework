import SwiftUI

public struct HeroCard: View {
    public let eyebrow: String
    public let title: String
    public let subtitle: String

    public init(eyebrow: String, title: String, subtitle: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .multilineTextAlignment(.leading)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.xLarge)
        .background(SentinelCardBackground(cornerRadius: 34))
    }
}

public struct FeatureCard: View {
    public let title: String
    public let bodyText: String
    public let systemImage: String

    public init(title: String, bodyText: String, systemImage: String) {
        self.title = title
        self.bodyText = bodyText
        self.systemImage = systemImage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: AppGrid.value(11), height: AppGrid.value(11))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(title)
                .font(.headline)

            Text(bodyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .padding(AppSpacing.large)
        .background(SentinelCardBackground(cornerRadius: 30))
    }
}

public struct AuthFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            content
        }
        .padding(AppSpacing.xLarge)
        .background(SentinelCardBackground(cornerRadius: 32))
    }
}

public struct ProfileHeader: View {
    public let displayName: String
    public let email: String

    public init(displayName: String, email: String) {
        self.displayName = displayName
        self.email = email
    }

    public var body: some View {
        HStack(spacing: AppSpacing.large) {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(.primary.opacity(0.82))
                }
                .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(displayName)
                    .font(.title2.weight(.bold))

                Text(email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(AppSpacing.xLarge)
        .background(SentinelCardBackground(cornerRadius: 30))
    }
}

public struct EventRowCard: View {
    public let title: String
    public let badge: String
    public let fixedTagTitle: String?
    public let isFixed: Bool
    public let time: String
    public let location: String?
    public let conflictTitle: String?
    public let action: (() -> Void)?

    public init(
        title: String,
        badge: String,
        fixedTagTitle: String? = nil,
        isFixed: Bool,
        time: String,
        location: String?,
        conflictTitle: String?,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.badge = badge
        self.fixedTagTitle = fixedTagTitle
        self.isFixed = isFixed
        self.time = time
        self.location = location
        self.conflictTitle = conflictTitle
        self.action = action
    }

    public var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        Text(title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.secondary)

                        if isFixed, let fixedTagTitle {
                            Text(fixedTagTitle)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.10), in: Capsule())
                                .foregroundStyle(.blue)
                        }
                    }

                    Text(time)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let location, !location.isEmpty {
                        Text(location)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: AppSpacing.medium)

                if let conflictTitle {
                    Text(conflictTitle)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                } else if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AppSpacing.large)
            .background(SentinelCardBackground(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }
}

public struct EmptyStateCard: View {
    public let title: String
    public let bodyText: String

    public init(title: String, bodyText: String) {
        self.title = title
        self.bodyText = bodyText
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.headline)

            Text(bodyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(SentinelCardBackground(cornerRadius: 26))
    }
}
