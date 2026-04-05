import ComposableArchitecture
import SwiftUI

struct HomeView: View {
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
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var signedOutContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            HStack {
                glassBadge(title: L10n.App.title)
                Spacer()
                Button {
                    store.send(.profileTapped)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title3.weight(.semibold))
                        .frame(width: AppGrid.value(12), height: AppGrid.value(12))
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Text(L10n.Home.signedOutHeroEyebrow)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(L10n.Home.signedOutHeroTitle)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)

                Text(L10n.Home.signedOutHeroBody)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button {
                    store.send(.profileTapped)
                } label: {
                    Label(L10n.Home.signInButton, systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.black.opacity(0.82))
            }
            .padding(AppSpacing.xLarge)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: AppStrokeWidth.standard)
            }

            HStack(spacing: AppSpacing.medium) {
                SignedOutFeatureCard(
                    title: L10n.Home.signedOutCardOneTitle,
                    bodyText: L10n.Home.signedOutCardOneBody,
                    systemImage: "calendar.badge.plus"
                )

                SignedOutFeatureCard(
                    title: L10n.Home.signedOutCardTwoTitle,
                    bodyText: L10n.Home.signedOutCardTwoBody,
                    systemImage: "brain.head.profile"
                )
            }
        }
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xLarge) {
            signedInHero

            HStack(spacing: AppSpacing.medium) {
                metricCard(
                    title: L10n.Home.metricTodayTitle,
                    value: "\(store.todayItems.count)",
                    detail: L10n.Home.todayCount(store.todayItems.count),
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

            allEventsSlot

            achievementsRail
        }
    }

    private var signedInHero: some View {
        HStack(alignment: .top, spacing: AppSpacing.large) {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(L10n.Home.heroTitle)
                    .font(.system(size: 50, weight: .bold, design: .rounded))

                Text(L10n.Home.heroSubtitle(store.displayName))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.send(.profileTapped)
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .frame(width: AppGrid.value(13), height: AppGrid.value(13))
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: AppStrokeWidth.standard)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Text(L10n.Home.todaySectionTitle)
                    .font(.title2.weight(.bold))

                Spacer()

                Button(L10n.Home.rebalanceButton) {}
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.25), lineWidth: AppStrokeWidth.standard)
                    }
                    .disabled(true)
                    .opacity(AppOpacity.disabled)

                if !store.allEventSections.isEmpty {
                    NavigationLink {
                        HomeAllEventsView(
                            batteryProgress: store.resourceBatteryProgress,
                            sections: store.allEventSections
                        )
                    } label: {
                        HStack(spacing: AppSpacing.xSmall) {
                            Text(L10n.Home.viewAllButton)
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.todayPreviewItems.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text(L10n.Home.emptyTodayTitle)
                        .font(.headline)
                    Text(L10n.Home.emptyTodayBody)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .modifier(FrostedCardModifier())
            } else {
                VStack(spacing: AppSpacing.medium) {
                    ForEach(store.todayPreviewItems) { item in
                        HomeHeroEventRow(item: item)
                    }
                }
            }
        }
    }

    private var allEventsSlot: some View {
        NavigationLink {
            HomeAllEventsView(
                batteryProgress: store.resourceBatteryProgress,
                sections: store.allEventSections
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
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .modifier(FrostedCardModifier())
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
                        HStack(spacing: AppSpacing.xSmall) {
                            Text(L10n.Home.viewAllButton)
                            Image(systemName: "chevron.right")
                        }
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

    private func frostedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(FrostedCardModifier())
    }

    private func glassBadge(title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
            }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
        }
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
            Color(uiColor: .systemGroupedBackground)

            LinearGradient(
                colors: [
                    Color(red: 0.80, green: 0.90, blue: 1.0),
                    Color(red: 0.92, green: 0.85, blue: 1.0),
                    Color(red: 0.95, green: 0.96, blue: 1.0),
                    Color(uiColor: .systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 420)
            .mask {
                LinearGradient(colors: [.white, .white, .clear], startPoint: .top, endPoint: .bottom)
            }

            Circle()
                .fill(Color.cyan.opacity(0.24))
                .frame(width: 260, height: 260)
                .blur(radius: 32)
                .offset(x: -110, y: -60)

            Circle()
                .fill(Color.pink.opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 40)
                .offset(x: 120, y: -40)
        }
    }
}

private struct FrostedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.large)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
            }
    }
}

private struct SignedOutFeatureCard: View {
    let title: String
    let bodyText: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: AppGrid.value(11), height: AppGrid.value(11))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            Text(title)
                .font(.headline)

            Text(bodyText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .padding(AppSpacing.large)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
        }
    }
}

private struct HomeHeroEventRow: View {
    let item: HomeScheduleItem

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(item.title)
                    .font(.body.weight(.semibold))
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.timeText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.medium)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: AppStrokeWidth.standard)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
        }
    }
}
