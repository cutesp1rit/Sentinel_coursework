import ComposableArchitecture
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
