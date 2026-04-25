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

    init(
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

struct HomeBatterySnapshot: Equatable, Sendable {
    var headline: String
    var detail: String
}

enum HomeBatteryState: Equatable, Sendable {
    case placeholder
    case unavailable
    case ready(HomeBatterySnapshot)

    var displaySnapshot: HomeBatterySnapshot {
        switch self {
        case .placeholder:
            return .init(
                headline: L10n.Home.batteryPlaceholderTitle,
                detail: L10n.Home.batteryPlaceholderBody
            )
        case .unavailable:
            return .init(
                headline: L10n.Home.batteryUnavailableTitle,
                detail: L10n.Home.batteryUnavailableBody
            )
        case let .ready(snapshot):
            return snapshot
        }
    }
}

struct HomeDayMarker: Equatable, Identifiable, Sendable {
    let id: Int
    let title: String
    let dayNumber: String
    let isToday: Bool
    var isSelected = false

    static let previewWeek: [Self] = {
        let calendar = Calendar.current
        let today = Date()

        return (0..<5).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }

            return Self(
                id: offset,
                title: date.formatted(.dateTime.weekday(.abbreviated)),
                dayNumber: date.formatted(.dateTime.day()),
                isToday: offset == 0,
                isSelected: offset == 0
            )
        }
    }()
}

struct HomeSnapshot: Equatable, Sendable {
    var title: String
    var detail: String
}

struct HomeEventDaySection: Equatable, Identifiable, Sendable {
    let id: String
    let date: Date
    var items: [HomeScheduleItem]

    var titleText: String {
        date.formatted(.dateTime.day().month(.wide))
    }
}

struct HomeAchievementHighlight: Equatable, Identifiable, Sendable {
    let id: UUID
    let groupTitle: String
    let icon: String
    let progressFraction: Double
    let progressText: String
    let subtitle: String
    let title: String
}
