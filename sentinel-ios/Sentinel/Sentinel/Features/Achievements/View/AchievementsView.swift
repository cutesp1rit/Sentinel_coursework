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
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.Achievements.title)
        .navigationBarTitleDisplayMode(.inline)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

private struct AchievementGroupCard: View {
    let group: AchievementGroup

    private var progressFraction: Double {
        guard let target = group.nextLockedLevel?.targetValue ?? group.levels.last?.targetValue,
              target > 0 else {
            return 1
        }
        return min(Double(group.currentValue) / Double(target), 1)
    }

    private var categoryTitle: String {
        group.category.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(categoryTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(groupTitle)
                    .font(.headline)

                Text(progressCopy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressFraction)

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(group.levels) { level in
                    AchievementLevelRow(level: level, currentValue: group.currentValue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.large)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }

    private var groupTitle: String {
        switch group.groupCode {
        case "events_created":
            return L10n.Achievements.eventsCreated
        case "ai_assisted":
            return L10n.Achievements.aiAssisted
        case "reminders":
            return L10n.Achievements.reminders
        case "active_days":
            return L10n.Achievements.activeDays
        default:
            return group.groupCode.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var progressCopy: String {
        if let nextLockedLevel = group.nextLockedLevel {
            return L10n.Achievements.progressToLevel(group.currentValue, nextLockedLevel.targetValue)
        }

        return L10n.Achievements.completedGroup
    }
}

private struct AchievementLevelRow: View {
    let level: AchievementLevel
    let currentValue: Int

    private var accentColor: Color {
        level.unlocked ? .green : .secondary
    }

    private var statusCopy: String {
        if level.unlocked {
            if let earnedAt = level.earnedAt {
                return L10n.Achievements.earnedAt(earnedAt.formatted(date: .abbreviated, time: .omitted))
            }
            return L10n.Achievements.unlocked
        }
        return L10n.Achievements.target(level.targetValue)
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

                    Text(L10n.Achievements.level(level.level))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                }

                Text(level.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(statusCopy)
                    .font(.caption)
                    .foregroundStyle(accentColor)
            }

            Spacer()

            if !level.unlocked {
                Text("\(currentValue)/\(level.targetValue)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
