import Foundation
import SentinelCore
import SwiftUI

extension HomeState {
    var scheduleSummaryRowModel: SummaryRowModel {
        SummaryRowModel(
            detail: scheduleSummaryDetail,
            leading: .value(todayItems.count.formatted(), .primary),
            title: L10n.Home.eventsRowTitle,
            titleTint: .primary
        )
    }

    var allEventSections: [HomeEventDaySection] {
        let grouped = Dictionary(grouping: schedule.upcomingItems) { item in
            Calendar.current.startOfDay(for: item.startDate)
        }

        return grouped.keys.sorted().map { day in
            HomeEventDaySection(
                id: day.formatted(.iso8601.year().month().day()),
                date: day,
                items: grouped[day, default: []].sorted { $0.startDate < $1.startDate }
            )
        }
    }

    var scheduleMetricDetail: String {
        if let firstItem = todayPreviewItems.first {
            return "Next: \(firstItem.timeText)"
        }
        return L10n.Home.emptyTodayBody
    }

    var scheduleMetricValue: String {
        todayPreviewItems.isEmpty ? L10n.Home.metricFreeValue : L10n.Home.metricNextValue
    }

    var todayItems: [HomeScheduleItem] {
        let calendar = Calendar.current
        return schedule.upcomingItems
            .filter { calendar.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    var displayDayStrip: [HomeDayMarker] {
        dayStrip.map { marker in
            var marker = marker
            marker.isSelected = marker.id == selectedDayID
            return marker
        }
    }

    var todayPreviewItems: [HomeScheduleItem] {
        Array(todayItems.prefix(3))
    }

    var todayPreviewRows: [TodayRowModel] {
        todayPreviewItems.map { item in
            TodayRowModel(
                id: "\(item.title)-\(item.startDate.timeIntervalSince1970)",
                location: item.subtitle == "Calendar" ? nil : item.subtitle,
                time: item.timeText,
                title: item.title
            )
        }
    }

    var todayTitle: String {
        let count = todayItems.count
        if count == 0 {
            return L10n.Home.noEventsToday
        }
        return L10n.Home.todayCount(count)
    }

    private var scheduleSummaryDetail: String {
        guard let item = nextRelevantScheduleItem else {
            return L10n.Home.emptyTodayBody
        }

        let now = Date()
        let relativeText: String
        if let endDate = item.endDate, item.startDate <= now, endDate > now {
            relativeText = L10n.Home.inProgress
        } else if abs(item.startDate.timeIntervalSince(now)) < 60 {
            relativeText = L10n.Home.startsNow
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            relativeText = formatter.localizedString(for: item.startDate, relativeTo: now)
        }

        return L10n.Home.scheduleDetail(item.title, relativeText)
    }

    private var nextRelevantScheduleItem: HomeScheduleItem? {
        let now = Date()
        return todayItems.first { item in
            if let endDate = item.endDate {
                return endDate > now
            }
            return item.startDate >= now
        } ?? schedule.upcomingItems.first
    }
}
