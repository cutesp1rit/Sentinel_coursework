import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    let bottomOverlayInset: CGFloat
    let showsChatLauncher: Bool
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
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack {
                brandBadge
                Spacer()
                profileButton
            }

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

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Home.signedOutCTAHeadline)
                    .font(.headline)

                Text(L10n.Home.signedOutCTABody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                PrimaryButton(L10n.Home.signInButton) {
                    store.send(.signInTapped)
                }

                SecondaryTextAction(L10n.Home.createAccountButton) {
                    store.send(.createAccountTapped)
                }
            }
            .padding(AppSpacing.large)
            .background(SentinelSurfaceCard())
        }
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack(alignment: .top, spacing: AppSpacing.medium) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
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

            HStack(spacing: AppSpacing.medium) {
                metricCard(
                    title: L10n.Home.metricTodayTitle,
                    value: "\(store.todayItems.count)",
                    detail: store.todayTitle,
                    tint: .primary
                )

                metricCard(
                    title: L10n.Home.metricBatteryTitle,
                    value: "\(Int(store.resourceBatteryProgress * 100))%",
                    detail: store.resourceBatteryTitle,
                    tint: .green,
                    systemImage: batterySymbolName
                )
            }

            todaySection

            if showsChatLauncher {
                PrimaryButton(L10n.Home.openChatButton) {
                    store.send(.chatTapped)
                }
            }

            allEventsCard

            achievementsRail
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text(L10n.Home.todaySectionTitle)
                    .font(.title3.weight(.bold))

                Spacer()

                Button(L10n.Home.rebalanceButton) {
                    store.send(.rebalanceTapped)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            if store.todayPreviewItems.isEmpty {
                EmptyStateCard(
                    title: L10n.Home.emptyTodayTitle,
                    bodyText: L10n.Home.emptyTodayBody
                )
            } else {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(store.todayPreviewItems) { item in
                        EventRowCard(
                            title: item.title,
                            badge: L10n.Calendar.eventTag,
                            time: item.timeText,
                            location: item.subtitle == "Calendar" ? nil : item.subtitle,
                            conflictTitle: nil,
                            action: nil
                        )
                    }
                }
            }
        }
    }

    private var allEventsCard: some View {
        Group {
            if let accessToken = store.accessToken {
                NavigationLink {
                    CalendarView(
                        store: Store(initialState: CalendarState(accessToken: accessToken)) {
                            CalendarReducer()
                        }
                    )
                } label: {
                    HStack(spacing: AppSpacing.medium) {
                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            Text(L10n.Home.allEventsTitle)
                                .font(.headline)
                            Text(L10n.Home.allEventsBody)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "calendar")
                            .font(.title3.weight(.semibold))

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.large)
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
                    }
                    .buttonStyle(.plain)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.medium) {
                    ForEach(store.nextAchievementHighlights.prefix(6)) { highlight in
                        HomeAchievementCard(highlight: highlight)
                    }
                }
                .padding(.vertical, AppSpacing.small)
            }
        }
    }

    private var brandBadge: some View {
        Text(L10n.App.title)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(.ultraThinMaterial, in: Capsule())
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

    private var batterySymbolName: String {
        let progress = store.resourceBatteryProgress
        switch progress {
        case ..<0.125:
            return "battery.0percent"
        case ..<0.375:
            return "battery.25percent"
        case ..<0.625:
            return "battery.50percent"
        case ..<0.875:
            return "battery.75percent"
        default:
            return "battery.100percent"
        }
    }

    private func metricCard(
        title: String,
        value: String,
        detail: String,
        tint: Color,
        systemImage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
            }

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 126, alignment: .topLeading)
        .padding(AppSpacing.large)
        .background(SentinelSurfaceCard())
    }
}

#Preview {
    HomeView(
        bottomOverlayInset: 200,
        showsChatLauncher: false,
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
                    Color(red: 0.82, green: 0.90, blue: 1.0),
                    Color(red: 0.90, green: 0.93, blue: 0.98),
                    Color(red: 0.98, green: 0.96, blue: 0.92),
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
                .fill(Color.orange.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 120, y: -30)
        }
    }
}

private struct SentinelSurfaceCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.26), lineWidth: AppStrokeWidth.standard)
            }
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
