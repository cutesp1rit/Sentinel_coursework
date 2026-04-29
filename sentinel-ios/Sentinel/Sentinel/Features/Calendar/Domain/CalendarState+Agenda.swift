import Foundation
import SentinelCore

extension CalendarState {
    static func sectionID(for date: Date) -> AgendaSection.ID {
        date.formatted(.iso8601.year().month().day())
    }

    static func visibleRangeDates(for selectedDate: Date) -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? selectedDate
        let rangeStart = calendar.date(byAdding: .day, value: -7, to: startOfMonth) ?? startOfMonth
        let rangeEndBase = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? selectedDate
        let rangeEnd = calendar.date(byAdding: .day, value: 14, to: rangeEndBase) ?? rangeEndBase

        var dates: [Date] = []
        var cursor = calendar.startOfDay(for: rangeStart)
        let end = calendar.startOfDay(for: rangeEnd)

        while cursor <= end {
            dates.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return dates
    }

    func agendaRow(for event: Event) -> AgendaRow {
        AgendaRow(
            id: event.id,
            badge: event.type == .reminder ? L10n.Calendar.reminderTag : L10n.Calendar.eventTag,
            conflictTitle: hasConflict(for: event) ? L10n.ChatSheet.conflict : nil,
            isFixed: event.isFixed,
            location: event.location,
            time: timeText(for: event),
            title: event.title
        )
    }

    func hasConflict(for event: Event) -> Bool {
        events.contains { other in
            guard other.id != event.id else { return false }
            guard Calendar.current.isDate(other.startAt, inSameDayAs: event.startAt) else { return false }
            let eventEnd = event.endAt ?? event.startAt
            let otherEnd = other.endAt ?? other.startAt
            return other.startAt < eventEnd && otherEnd > event.startAt
        }
    }

    func timeText(for event: Event) -> String {
        if event.allDay {
            return L10n.Calendar.allDay
        }
        if let endAt = event.endAt {
            return "\(event.startAt.formatted(date: .omitted, time: .shortened)) - \(endAt.formatted(date: .omitted, time: .shortened))"
        }
        if event.type == .reminder {
            return event.startAt.formatted(date: .omitted, time: .shortened)
        }
        return event.startAt.formatted(date: .abbreviated, time: .shortened)
    }
}
