import SwiftUI

struct HomeAllEventsView: View {
    let batteryProgress: Double
    let sections: [HomeEventDaySection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        HStack(alignment: .center, spacing: AppSpacing.medium) {
                            Text(section.date.formatted(.dateTime.day().month(.wide)))
                                .font(.title3.weight(.semibold))

                            Spacer()

                            Text("\(Int(batteryProgress * 100))%")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.green)

                            Button(L10n.Home.rebalanceButton) {}
                                .buttonStyle(.plain)
                                .padding(.horizontal, AppSpacing.medium)
                                .padding(.vertical, AppSpacing.small)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(Color.white.opacity(0.28), lineWidth: AppStrokeWidth.standard)
                                }
                                .disabled(true)
                                .opacity(AppOpacity.disabled)
                        }

                        VStack(spacing: AppSpacing.small) {
                            ForEach(section.items) { item in
                                HomeTimelineRow(item: item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.xLarge)
        }
        .background(HomeTopGradientBackground().ignoresSafeArea())
        .navigationTitle(L10n.Home.allEventsTitle)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct HomeTimelineRow: View {
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
