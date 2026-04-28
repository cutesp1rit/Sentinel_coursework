import Foundation

enum HomeScheduleAccess: Equatable, Sendable {
    case notRequested
    case granted
    case denied
}

struct HomeScheduleItem: Equatable, Identifiable, Sendable {
    let id: UUID
    var endDate: Date?
    var startDate: Date
    var title: String
    var timeText: String
    var subtitle: String

    nonisolated init(
        id: UUID = UUID(),
        endDate: Date? = nil,
        startDate: Date = .now,
        title: String,
        timeText: String,
        subtitle: String
    ) {
        self.id = id
        self.endDate = endDate
        self.startDate = startDate
        self.title = title
        self.timeText = timeText
        self.subtitle = subtitle
    }
}

struct HomeScheduleState: Equatable, Sendable {
    var access: HomeScheduleAccess = .notRequested
    var isLoading = false
    var errorMessage: String?
    var upcomingItems: [HomeScheduleItem] = []

    var emptyStateCopy: HomeSnapshot {
        if isLoading {
            return HomeSnapshot(
                title: L10n.Home.loadingTitle,
                detail: L10n.Home.loadingBody
            )
        }

        if errorMessage != nil {
            return HomeSnapshot(
                title: L10n.Home.calendarErrorTitle,
                detail: L10n.Home.calendarErrorBody
            )
        }

        switch access {
        case .notRequested:
            return HomeSnapshot(
                title: L10n.Home.connectCalendarTitle,
                detail: L10n.Home.connectCalendarBody
            )
        case .denied:
            return HomeSnapshot(
                title: L10n.Home.calendarDeniedTitle,
                detail: L10n.Home.calendarDeniedBody
            )
        case .granted:
            return HomeSnapshot(
                title: L10n.Home.noEventsTitle,
                detail: L10n.Home.noEventsBody
            )
        }
    }
}
