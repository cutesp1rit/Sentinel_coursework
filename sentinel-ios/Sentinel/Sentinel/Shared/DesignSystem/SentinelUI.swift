import SwiftUI

struct HeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
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

struct FeatureCard: View {
    let title: String
    let bodyText: String
    let systemImage: String

    var body: some View {
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

struct PrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
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

struct SecondaryTextAction: View {
    let prompt: String?
    let title: String
    let action: () -> Void

    init(
        _ title: String,
        prompt: String? = nil,
        action: @escaping () -> Void
    ) {
        self.prompt = prompt
        self.title = title
        self.action = action
    }

    var body: some View {
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

struct AuthFormCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            content
        }
        .padding(AppSpacing.xLarge)
        .background(SentinelCardBackground(cornerRadius: 32))
    }
}

struct SheetHeader: View {
    let title: String
    let subtitle: String?
    let trailingTitle: String?
    let onTrailingTap: (() -> Void)?

    init(
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

    var body: some View {
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

struct ProfileHeader: View {
    let displayName: String
    let email: String

    var body: some View {
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

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
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

struct SettingsRow<Accessory: View>: View {
    let systemImage: String
    let title: String
    let tint: Color
    let accessory: Accessory
    let action: (() -> Void)?

    init(
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

    var body: some View {
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

struct AccountActionRow: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let tint: Color
    let action: () -> Void

    var body: some View {
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

enum SelectedChatListRowState: Equatable {
    case selected
    case regular
}

struct ChatListRow: View {
    let title: String
    let subtitle: String?
    let state: SelectedChatListRowState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small + 2)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var rowBackground: some View {
        switch state {
        case .selected:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppPlatformColor.secondaryGroupedBackground)
        case .regular:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.clear)
        }
    }
}

struct WeekStripDay: Equatable, Identifiable {
    let id: String
    let date: Date
    let weekday: String
    let dayNumber: String
    let isSelected: Bool
    let isToday: Bool
}

struct WeekStrip: View {
    let days: [WeekStripDay]
    let onSelect: (Date) -> Void
    let onSwipe: (Int) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            ForEach(days) { day in
                Button {
                    onSelect(day.date)
                } label: {
                    VStack(spacing: AppSpacing.xSmall) {
                        Text(day.weekday)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(day.isSelected ? .white.opacity(0.8) : .secondary)

                        Text(day.dayNumber)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(day.isSelected ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(dayBackground(for: day))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.small)
        .background(SentinelCardBackground(cornerRadius: 26))
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    if value.translation.width <= -40 {
                        onSwipe(1)
                    } else if value.translation.width >= 40 {
                        onSwipe(-1)
                    }
                }
        )
    }

    @ViewBuilder
    private func dayBackground(for day: WeekStripDay) -> some View {
        if day.isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.84))
        } else if day.isToday {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.clear)
        }
    }
}

struct AgendaDayHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Text(title)
                .font(.title3.weight(.bold))

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EventRowCard: View {
    let title: String
    let badge: String
    let isFixed: Bool
    let time: String
    let location: String?
    let conflictTitle: String?
    let action: (() -> Void)?

    var body: some View {
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

                        if isFixed {
                            Text(L10n.Calendar.fixedTag)
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

struct EmptyStateCard: View {
    let title: String
    let bodyText: String

    var body: some View {
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

private struct SentinelCardBackground: View {
    let cornerRadius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppPlatformColor.systemBackground)
    }
}

#if os(iOS)
let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.topBarLeading
let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.topBarTrailing
#else
let sentinelToolbarLeadingPlacement = ToolbarItemPlacement.automatic
let sentinelToolbarTrailingPlacement = ToolbarItemPlacement.automatic
#endif

extension View {
    @ViewBuilder
    func sentinelInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelLargeNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelHiddenNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarHidden(true)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelNavigationBarToolbarVisibility(_ visibility: Visibility) -> some View {
        #if os(iOS)
        self.toolbar(visibility, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func sentinelNavigationBarMaterialBackground() -> some View {
        #if os(iOS)
        self
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }
}
