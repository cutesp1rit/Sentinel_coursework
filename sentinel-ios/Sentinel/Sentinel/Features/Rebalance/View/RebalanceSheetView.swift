import ComposableArchitecture
import SwiftUI

struct RebalanceSheetView: View {
    let onClose: () -> Void
    let store: StoreOf<RebalanceFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    Text(L10n.Rebalance.subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    daySelectionSection

                    if let errorMessage = store.errorMessage {
                        banner(errorMessage, tint: .red.opacity(0.12), foreground: .red)
                    }

                    PrimaryButton(
                        store.preview == nil ? L10n.Rebalance.previewButton : L10n.Rebalance.refreshButton,
                        isEnabled: store.canPreview
                    ) {
                        store.send(.previewTapped)
                    }

                    if let preview = store.preview {
                        previewSection(preview)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.xLarge)
                .padding(.bottom, AppSpacing.xLarge)
            }
            .background(HomeTopGradientBackground().ignoresSafeArea())
            .navigationTitle(L10n.Rebalance.title)
            .sentinelInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: sentinelToolbarLeadingPlacement) {
                    Button(L10n.Profile.closeButton, action: onClose)
                }
            }
        }
        .task {
            store.send(.onAppear)
        }
    }

    private var daySelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(L10n.Rebalance.daySelectionTitle)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.medium) {
                ForEach(store.availableDays) { day in
                    Button {
                        store.send(.selectedDayToggled(day.id))
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack {
                                Text(day.weekdayText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if day.isToday {
                                    Text(L10n.Calendar.today)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("\(day.dayNumber) \(day.monthText)")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)

                            Text(L10n.Rebalance.eventCount(day.eventCount))
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let batteryScore = day.batteryScore {
                                Text(L10n.Rebalance.energyLevel(Int((batteryScore * 100).rounded())))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.large)
                        .background(dayBackground(isSelected: store.selectedDayIDs.contains(day.id)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func previewSection(_ preview: RebalancePreview) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(L10n.Rebalance.previewTitle)
                .font(.headline)

            banner(
                preview.summary,
                tint: .secondary.opacity(0.10),
                foreground: .primary
            )

            Text(L10n.Rebalance.changeSummary(preview.changedCount, preview.unchangedCount))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(preview.proposed.filter(\.changed)) { event in
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(event.title)
                        .font(.body.weight(.semibold))
                    Text(L10n.Rebalance.originalTime(Self.timeRange(event.originalStartAt, event.originalEndAt)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(L10n.Rebalance.newTime(Self.timeRange(event.startAt, event.endAt)))
                        .font(.footnote.weight(.semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.large)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(AppPlatformColor.systemBackground)
                )
            }

            if preview.changedCount == 0 {
                EmptyStateCard(
                    title: L10n.Rebalance.noChangesTitle,
                    bodyText: L10n.Rebalance.noChangesBody
                )
            }

            PrimaryButton(L10n.Rebalance.applyButton, isEnabled: store.canApply) {
                store.send(.applyTapped)
            }
        }
    }

    private func banner(_ message: String, tint: Color, foreground: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(foreground)
            .padding(AppSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(tint)
            )
    }

    @ViewBuilder
    private func dayBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(isSelected ? Color.primary.opacity(0.10) : AppPlatformColor.systemBackground)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.18), lineWidth: AppStrokeWidth.standard)
                }
            }
    }

    private static func timeRange(_ startAt: Date, _ endAt: Date?) -> String {
        if let endAt {
            return "\(startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        return startAt.formatted(date: .abbreviated, time: .shortened)
    }
}
