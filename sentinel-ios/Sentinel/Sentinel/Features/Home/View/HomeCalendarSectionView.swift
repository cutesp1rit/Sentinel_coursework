import ComposableArchitecture
import SwiftUI

struct HomeCalendarSectionView: View {
    let dayStrip: [HomeDayMarker]
    let selectedDayID: Int
    let onSelectDay: (Int) -> Void

    var body: some View {
        HomeSectionCard(title: L10n.Home.calendarTitle) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    ForEach(dayStrip) { marker in
                        Button {
                            onSelectDay(marker.id)
                        } label: {
                            VStack(spacing: AppSpacing.xSmall) {
                                Text(marker.title)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(isSelected(marker) ? .primary : .secondary)

                                Text(marker.dayNumber)
                                    .font(.body.weight(.semibold))
                                    .frame(width: AppGrid.value(10), height: AppGrid.value(10))
                                    .background(
                                        isSelected(marker)
                                            ? Color.accentColor.opacity(0.14)
                                            : AppPlatformColor.tertiaryGroupedBackground
                                    )
                                    .clipShape(Circle())
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(L10n.Home.calendarPreviewBody)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func isSelected(_ marker: HomeDayMarker) -> Bool {
        marker.id == selectedDayID
    }
}
