import Foundation

enum HomeScheduleAccess: Equatable {
    case notRequested
    case granted
    case denied
}

struct HomeScheduleItem: Equatable, Identifiable {
    let id: UUID
    var title: String
    var timeText: String
    var subtitle: String

    init(
        id: UUID = UUID(),
        title: String,
        timeText: String,
        subtitle: String
    ) {
        self.id = id
        self.title = title
        self.timeText = timeText
        self.subtitle = subtitle
    }
}

struct HomeScheduleState: Equatable {
    var access: HomeScheduleAccess = .notRequested
    var isLoading = false
    var errorMessage: String?
    var upcomingItems: [HomeScheduleItem] = []
}

struct HomeBatterySnapshot: Equatable {
    var headline: String
    var detail: String
}

enum HomeBatteryState: Equatable {
    case placeholder
    case unavailable
    case ready(HomeBatterySnapshot)
}

struct HomeDayMarker: Equatable, Identifiable {
    let id: Int
    let title: String
    let dayNumber: String
    let isToday: Bool

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
                isToday: offset == 0
            )
        }
    }()
}

struct HomeSnapshot: Equatable {
    var title: String
    var detail: String
}
