import ComposableArchitecture
import Foundation
import SwiftUI

@ObservableState
struct HomeState: Equatable {
    struct SummaryRowModel: Equatable {
        enum Leading: Equatable {
            case icon(String, Color)
            case value(String, Color)
        }

        let detail: String
        let leading: Leading
        let title: String
        let titleTint: Color
    }

    struct MetricCardModel: Equatable {
        let detail: String
        let systemImage: String?
        let tint: Color
        let title: String
        let value: String
    }

    struct TodayRowModel: Equatable, Identifiable {
        let id: String
        let location: String?
        let time: String
        let title: String
    }

    var accessToken: String?
    var achievementGroups: [AchievementGroup] = []
    var schedule = HomeScheduleState()
    var battery = HomeBatteryState.hidden
    var dayStrip = HomeDayMarker.previewWeek
    var selectedDayID = 0
    var userEmail: String?
}
