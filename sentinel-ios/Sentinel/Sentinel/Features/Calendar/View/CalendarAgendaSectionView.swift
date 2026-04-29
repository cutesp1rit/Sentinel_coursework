import SentinelUI
import SentinelCore
import SwiftUI

struct CalendarAgendaSectionView: View {
    let section: CalendarState.AgendaSection
    let selectedDate: Date
    let batteryState: DayBatteryBadgeState
    let onBatteryRequested: () -> Void
    let onDelete: (UUID) -> Void
    let onEdit: (UUID) -> Void
    let onVisibleDateChanged: (Date) -> Void

    var body: some View {
        Section {
            VStack(spacing: AppSpacing.medium) {
                if section.rows.isEmpty {
                    if Calendar.current.isDate(section.date, inSameDayAs: selectedDate) {
                        EmptyStateCard(
                            title: L10n.Calendar.emptySelectedDayTitle,
                            bodyText: L10n.Calendar.emptySelectedDayBody
                        )
                    } else {
                        Color.clear
                            .frame(height: AppSpacing.small)
                    }
                } else {
                    ForEach(section.rows) { row in
                        EventRowCard(
                            title: row.title,
                            badge: row.badge,
                            fixedTagTitle: L10n.Calendar.fixedTag,
                            isFixed: row.isFixed,
                            time: row.time,
                            location: row.location,
                            conflictTitle: row.conflictTitle
                        ) {
                            onEdit(row.id)
                        }
                        .contextMenu {
                            Button(L10n.Calendar.editEvent) {
                                onEdit(row.id)
                            }
                            Button(L10n.Calendar.deleteEvent, role: .destructive) {
                                onDelete(row.id)
                            }
                        }
                    }
                }
            }
            .onAppear {
                onVisibleDateChanged(section.date)
            }
        } header: {
            AgendaDayHeader(
                title: section.title,
                subtitle: section.subtitle
            ) {
                ResourceBatteryInlineBadge(state: batteryState)
            }
            .onAppear(perform: onBatteryRequested)
            .id(section.id)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CalendarSectionOffsetKey.self,
                        value: [section.id: proxy.frame(in: .named("calendarScroll")).minY]
                    )
                }
            )
            .padding(.top, AppSpacing.small)
            .padding(.bottom, AppSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
