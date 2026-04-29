import SentinelUI
import SwiftUI

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

struct AgendaDayHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                Text(title)
                    .font(.title3.weight(.bold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.medium)

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
