import ComposableArchitecture
import SwiftUI

struct AchievementsView: View {
    let store: StoreOf<AchievementsReducer>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                summaryCard

                content
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(AppPlatformColor.systemGroupedBackground.ignoresSafeArea())
        .navigationTitle(L10n.Achievements.title)
        .sentinelInlineNavigationTitle()
        .task {
            store.send(.onAppear)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(L10n.Achievements.summaryTitle)
                .font(.headline)

            Text(L10n.Achievements.summaryBody(store.totalUnlockedCount, store.totalLevelCount))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.groups.isEmpty {
            loadingCard
        } else if let errorMessage = store.errorMessage, store.groups.isEmpty {
            errorCard(message: errorMessage)
        } else if store.groups.isEmpty {
            emptyCard
        } else {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(store.groups) { group in
                    AchievementGroupCard(group: group)
                }
            }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
            Text(L10n.Achievements.loading)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xLarge)
    }

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(L10n.Achievements.errorTitle)
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(L10n.ChatSheet.retry) {
                store.send(.retryTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(L10n.Achievements.emptyTitle)
                .font(.headline)

            Text(L10n.Achievements.emptyBody)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

private struct AchievementGroupCard: View {
    let group: AchievementGroup

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(group.categoryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(group.displayTitle)
                    .font(.headline)

                Text(group.progressCopy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: group.progressFraction)

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(group.levels) { level in
                    AchievementLevelRow(
                        groupTitle: group.displayTitle,
                        level: level,
                        currentValue: group.currentValue
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(AppPlatformColor.secondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

private struct AchievementLevelRow: View {
    let groupTitle: String
    let level: AchievementLevel
    let currentValue: Int

    private var accentColor: Color {
        level.unlocked ? .green : .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text(level.icon)
                .font(.title3)
                .frame(width: AppGrid.value(8), height: AppGrid.value(8))
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(spacing: AppSpacing.small) {
                    Text(level.title)
                        .font(.subheadline.weight(.semibold))

                    Text(level.levelTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                }

                Text(level.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(level.statusCopy)
                    .font(.caption)
                    .foregroundStyle(accentColor)
            }

            Spacer()

            if level.unlocked {
                ShareLink(
                    item: L10n.Achievements.shareMessage(level.title, level.levelTitle, L10n.App.title),
                    subject: Text(groupTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: AppGrid.value(8), height: AppGrid.value(8))
                }
                .buttonStyle(.plain)
            } else {
                Text("\(currentValue)/\(level.targetValue)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
