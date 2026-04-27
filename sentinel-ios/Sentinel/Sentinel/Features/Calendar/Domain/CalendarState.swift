import ComposableArchitecture
import CoreGraphics
import Foundation

@ObservableState
struct CalendarState: Equatable {
    struct AgendaRow: Equatable, Identifiable {
        let id: UUID
        let badge: String
        let conflictTitle: String?
        let isFixed: Bool
        let location: String?
        let time: String
        let title: String
    }

    struct AgendaSection: Equatable, Identifiable {
        let id: String
        let date: Date
        let rows: [AgendaRow]

        var title: String {
            date.formatted(.dateTime.day().month(.wide))
        }

        var subtitle: String {
            date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        }
    }

    @ObservableState
    struct Editor: Equatable {
        var allDay = false
        var description = ""
        var endDate = Date().addingTimeInterval(60 * 60)
        var eventID: UUID?
        var isFixed = false
        var location = ""
        var startDate = Date()
        var title = ""
        var type: EventKind = .event

        init(event: Event? = nil) {
            eventID = event?.id
            title = event?.title ?? ""
            description = event?.description ?? ""
            startDate = event?.startAt ?? .now
            endDate = event?.endAt ?? (event?.startAt.addingTimeInterval(60 * 60) ?? .now.addingTimeInterval(60 * 60))
            allDay = event?.allDay ?? false
            isFixed = event?.isFixed ?? false
            type = event?.type ?? .event
            location = event?.location ?? ""
        }

        var payload: EventMutationPayload {
            EventMutationPayload(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                startAt: startDate,
                endAt: allDay || type == .reminder ? nil : endDate,
                allDay: allDay,
                type: type,
                location: location.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                isFixed: isFixed,
                source: eventID == nil ? "user" : nil
            )
        }
    }

    let accessToken: String
    var activeDayBatterySectionID: AgendaSection.ID?
    var dayBatteryCache: [AgendaSection.ID: DayBatteryCacheEntry] = [:]
    var editor: Editor?
    var errorMessage: String?
    var events: [Event] = []
    var isInlineMonthPickerVisible = false
    var isLoading = false
    var pendingScrollSectionID: AgendaSection.ID?
    var queuedDayBatterySectionIDs: [AgendaSection.ID] = []
    var selectedDate = Date()

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

    func batteryRequest(for sectionID: AgendaSection.ID) -> BatteryDayRequest? {
        guard let section = agendaSections.first(where: { $0.id == sectionID }) else {
            return nil
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: section.date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        let entries = events
            .filter { calendar.isDate($0.startAt, inSameDayAs: startDate) }
            .sorted { $0.startAt < $1.startAt }
            .map(BatteryScheduleEntry.init(event:))

        return BatteryDayRequest(
            dayID: sectionID,
            endDate: endDate,
            entries: entries,
            startDate: startDate
        )
    }

    func dayBatteryState(for sectionID: AgendaSection.ID) -> DayBatteryBadgeState {
        dayBatteryCache[sectionID]?.state ?? .hidden
    }

    static func sectionID(for date: Date) -> AgendaSection.ID {
        date.formatted(.iso8601.year().month().day())
    }

    private static func visibleRangeDates(for selectedDate: Date) -> [Date] {
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

    private func agendaRow(for event: Event) -> AgendaRow {
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

    private func hasConflict(for event: Event) -> Bool {
        events.contains { other in
            guard other.id != event.id else { return false }
            guard Calendar.current.isDate(other.startAt, inSameDayAs: event.startAt) else { return false }
            let eventEnd = event.endAt ?? event.startAt
            let otherEnd = other.endAt ?? other.startAt
            return other.startAt < eventEnd && otherEnd > event.startAt
        }
    }

    private func timeText(for event: Event) -> String {
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
