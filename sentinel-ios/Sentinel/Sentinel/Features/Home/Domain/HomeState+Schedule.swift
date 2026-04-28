import Foundation

extension HomeState {
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
}
