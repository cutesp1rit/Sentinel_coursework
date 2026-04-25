import ComposableArchitecture
import Foundation

@ObservableState
struct CalendarState: Equatable {
    enum DisplayMode: String, CaseIterable, Equatable, Identifiable {
        case week
        case month

        var id: Self { self }
    }

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
    var anchorDate = Date()
    var displayMode: DisplayMode = .week
    var editor: Editor?
    var errorMessage: String?
    var events: [Event] = []
    var isLoading = false

    var navigationTitle: String {
        displayMode == .week ? L10n.Calendar.weekTitle : L10n.Calendar.monthTitle
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
