import ComposableArchitecture
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let bottomOverlayInset: CGFloat
    let store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                HomeTopGradientBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
                        if store.isAuthenticated {
                            signedInContent
                        } else {
                            signedOutContent
                        }
                    }
                    .padding(.horizontal, AppSpacing.large)
                    .padding(.top, AppSpacing.xLarge)
                    .padding(.bottom, max(bottomOverlayInset, AppSpacing.xLarge))
                }
                .scrollIndicators(.hidden)
            }
            .sentinelHiddenNavigationBar()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !store.isAuthenticated {
                signedOutCTA
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            store.send(.batteryRefreshRequested)
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HeroCard(
                eyebrow: L10n.Home.signedOutHeroEyebrow,
                title: L10n.Home.signedOutHeroTitle,
                subtitle: L10n.Home.signedOutHeroBody
            )

            HStack(alignment: .top, spacing: AppSpacing.medium) {
                FeatureCard(
                    title: L10n.Home.signedOutCardOneTitle,
                    bodyText: L10n.Home.signedOutCardOneBody,
                    systemImage: "bubble.left.and.text.bubble.right"
                )

                FeatureCard(
                    title: L10n.Home.signedOutCardTwoTitle,
                    bodyText: L10n.Home.signedOutCardTwoBody,
                    systemImage: "calendar.badge.clock"
                )
            }
        }
    }

    private var signedOutCTA: some View {
        HStack(spacing: AppSpacing.medium) {
            PrimaryButton(L10n.Home.signInButton) {
                store.send(.signInTapped)
            }

            PrimaryButton(L10n.Home.createAccountButton) {
                store.send(.createAccountTapped)
            }
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.top, AppSpacing.medium)
        .padding(.bottom, AppSpacing.large)
        .background(.ultraThinMaterial)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(store.currentDateText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(L10n.Home.heroTitle)
                        .font(.system(size: 48, weight: .bold, design: .rounded))

                    Text(L10n.Home.heroSubtitle(store.displayName))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                profileButton
            }

            summaryRows

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                todaySection
                rebalanceFeatureCard
            }

            achievementsRail
        }
    }

    private var summaryRows: some View {
        VStack(spacing: AppSpacing.medium) {
            summaryRow(model: store.scheduleSummaryRowModel)

            if let batteryRow = store.batterySummaryRowModel {
                batterySummaryRow(model: batteryRow)
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(L10n.Home.todaySectionTitle)
                    .font(.title3.weight(.bold))

                Spacer()

                allEventsShortcut
            }

            if store.todayPreviewItems.isEmpty {
                EmptyStateCard(
                    title: L10n.Home.emptyTodayTitle,
                    bodyText: L10n.Home.emptyTodayBody
                )
            } else {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(store.todayPreviewRows) { item in
                        EventRowCard(
                            title: item.title,
                            badge: L10n.Calendar.eventTag,
                            isFixed: false,
                            time: item.time,
                            location: item.location,
                            conflictTitle: nil,
                            action: nil
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var allEventsShortcut: some View {
        if let accessToken = store.accessToken {
            NavigationLink {
                CalendarView(
                    store: Store(initialState: CalendarState(accessToken: accessToken)) {
                        CalendarReducer()
                    }
                )
            } label: {
                HStack(spacing: AppSpacing.small) {
                    Text(L10n.Home.allEventsTitle)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var rebalanceFeatureCard: some View {
        Group {
            Button {
                store.send(.rebalanceTapped)
            } label: {
                HStack(alignment: .top, spacing: AppSpacing.medium) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.blue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                        Text(L10n.Home.rebalanceTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(L10n.Home.rebalanceFeatureBody)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: AppSpacing.medium)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, AppSpacing.xSmall)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium)
        .background(SentinelSurfaceCard())
    }

    private var achievementsRail: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(L10n.Home.achievementsRailTitle)
                    .font(.title3.weight(.bold))
                Spacer()

                if let accessToken = store.accessToken {
                    NavigationLink {
                        AchievementsView(
                            store: Store(initialState: AchievementsState(accessToken: accessToken)) {
                                AchievementsReducer()
                            }
                        )
                    } label: {
                        Text(L10n.Home.viewAllButton)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.medium) {
                    ForEach(store.achievementPreviewHighlights) { highlight in
                        HomeAchievementCard(highlight: highlight)
                    }
                }
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.small)
            }
            .padding(.horizontal, -AppSpacing.large)
            .scrollClipDisabled()
        }
    }
    private var profileButton: some View {
        Button {
            store.send(.profileTapped)
        } label: {
            Image(systemName: store.isAuthenticated ? "person.crop.circle.fill" : "person.crop.circle")
                .font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func batterySummaryRow(model: HomeState.SummaryRowModel) -> some View {
        if store.isBatteryMetricActionable {
            Button {
                openSystemSettings()
            } label: {
                summaryRowContent(model: model)
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.Home.batteryOpenSettingsHint)
        } else {
            summaryRowContent(model: model)
        }
    }

    private func summaryRow(model: HomeState.SummaryRowModel) -> some View {
        summaryRowContent(model: model)
    }

    private func summaryRowContent(model: HomeState.SummaryRowModel) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Text(model.value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(model.tint)
                .fixedSize()

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                    Text(model.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    if let systemImage = model.systemImage {
                        Image(systemName: systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(model.tint)
                    }
                }

                Text(model.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppSpacing.medium)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(AppSpacing.large)
        .background(SentinelSurfaceCard())
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}

#Preview {
    HomeView(
        bottomOverlayInset: 200,
        store: Store(initialState: HomeState()) {
            HomeReducer()
        }
    )
}

struct HomeTopGradientBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            AppPlatformColor.systemGroupedBackground

            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 1.0),
                    Color(red: 0.90, green: 0.88, blue: 1.0),
                    Color(red: 0.93, green: 0.97, blue: 1.0),
                    AppPlatformColor.systemGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 420)
            .mask {
                LinearGradient(colors: [.white, .white, .clear], startPoint: .top, endPoint: .bottom)
            }

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(x: -110, y: -40)

            Circle()
                .fill(Color.pink.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 120, y: -30)
        }
    }
}

private struct SentinelSurfaceCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(AppPlatformColor.systemBackground)
    }
}

private struct HomeAchievementCard: View {
    let highlight: HomeAchievementHighlight

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(highlight.icon)
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(highlight.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)

                Text(highlight.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: highlight.progressFraction)
                .tint(.green)

            Text(highlight.progressText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 180, alignment: .leading)
        .padding(AppSpacing.large)
        .background(SentinelSurfaceCard())
    }
}
