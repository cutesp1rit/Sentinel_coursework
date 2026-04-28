import Foundation

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
