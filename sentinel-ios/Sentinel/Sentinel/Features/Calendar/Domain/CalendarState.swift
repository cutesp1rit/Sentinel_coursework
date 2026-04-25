import ComposableArchitecture
import Foundation

@ObservableState
struct CalendarState: Equatable {
    @ObservableState
    struct Editor: Equatable {
        var allDay = false
        var description = ""
        var endDate = Date().addingTimeInterval(60 * 60)
        var eventID: UUID?
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
                isFixed: false,
                source: eventID == nil ? "user" : nil
            )
        }
    }

    let accessToken: String
    var editor: Editor?
    var errorMessage: String?
    var events: [Event] = []
    var isLoading = false
    var isMonthPickerPresented = false
    var selectedDate = Date()

    var navigationTitle: String {
        L10n.Calendar.title
    }

    var selectedMonthLabel: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
