import CoreGraphics
import SentinelCore
import Foundation

extension CalendarState {
    var navigationTitle: String {
        L10n.Calendar.title
    }

    var selectedMonthLabel: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }

    var weekStripDays: [WeekStripDay] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate

        return (0 ..< 7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startOfWeek) else {
                return nil
            }

            return WeekStripDay(
                id: date.formatted(.iso8601.year().month().day()),
                date: date,
                weekday: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: date.formatted(.dateTime.day()),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    var selectedDayRows: [AgendaRow] {
        let calendar = Calendar.current
        return events
            .filter { calendar.isDate($0.startAt, inSameDayAs: selectedDate) }
            .sorted { $0.startAt < $1.startAt }
            .map(agendaRow(for:))
    }

    var agendaSections: [AgendaSection] {
        let grouped = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.startAt) }
        return Self.visibleRangeDates(for: selectedDate).map { date in
            AgendaSection(
                id: date.formatted(.iso8601.year().month().day()),
                date: date,
                rows: grouped[date, default: []]
                    .sorted { $0.startAt < $1.startAt }
                    .map(agendaRow(for:))
            )
        }
    }

    var selectedSectionID: AgendaSection.ID {
        Self.sectionID(for: selectedDate)
    }

    func visibleSectionDate(for offsets: [AgendaSection.ID: CGFloat]) -> Date? {
        let sortedSections = agendaSections.compactMap { section -> (Date, CGFloat)? in
            guard let offset = offsets[section.id] else { return nil }
            return (section.date, offset)
        }

        let positive = sortedSections
            .filter { $0.1 >= 0 }
            .min { $0.1 < $1.1 }

        if let positive {
            return positive.0
        }

        return sortedSections
            .max { $0.1 < $1.1 }?
            .0
    }

    func hasSection(for date: Date) -> Bool {
        agendaSections.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func dayBatteryState(for sectionID: AgendaSection.ID) -> DayBatteryBadgeState {
        dayBatteryCache[sectionID]?.state ?? .hidden
    }
}
