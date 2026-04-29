import ComposableArchitecture
import SentinelCore
import Foundation

extension RebalanceFeature {
    @ObservableState
    struct State: Equatable {
        struct DayItem: Equatable, Identifiable {
            let batteryRequest: BatteryDayRequest
            let id: String
            let date: Date
            let eventCount: Int
            let isToday: Bool

            var dayNumber: String {
                date.formatted(.dateTime.day())
            }

            var monthText: String {
                date.formatted(.dateTime.month(.abbreviated))
            }

            var weekdayText: String {
                date.formatted(.dateTime.weekday(.abbreviated))
            }
        }

        var accessToken: String
        var activeDayBatteryID: DayItem.ID?
        var availableDays: [DayItem] = []
        var dayBatteryCache: [DayItem.ID: DayBatteryCacheEntry] = [:]
        var defaultPrompt = ""
        var errorMessage: String?
        var isApplying = false
        var isLoading = false
        var isPreviewPresented = false
        var preview: RebalancePreview?
        var queuedDayBatteryIDs: [DayItem.ID] = []
        var selectedDayIDs: Set<DayItem.ID> = []

        var canApply: Bool {
            preview?.changedCount ?? 0 > 0 && !isApplying
        }

        var canPreview: Bool {
            !selectedDayIDs.isEmpty && !isLoading && !isApplying
        }

        var selectedDays: [DayItem] {
            availableDays.filter { selectedDayIDs.contains($0.id) }
        }

        func batteryScore(for dayID: DayItem.ID) -> Double? {
            guard case let .ready(percentage) = dayBatteryState(for: dayID) else {
                return nil
            }
            return Double(percentage) / 100
        }

        func batteryRequest(for dayID: DayItem.ID) -> BatteryDayRequest? {
            availableDays.first(where: { $0.id == dayID })?.batteryRequest
        }

        func dayBatteryState(for dayID: DayItem.ID) -> DayBatteryBadgeState {
            dayBatteryCache[dayID]?.state ?? .hidden
        }
    }

    enum Action: Equatable {
        case applyCompleted
        case applyFailed(String)
        case applyTapped
        case dayBatteryLoaded(State.DayItem.ID, String, DayBatteryBadgeState)
        case dayBatteryRequested(State.DayItem.ID)
        case defaultPromptLoaded(AppSettings)
        case delegate(Delegate)
        case daysLoaded([State.DayItem])
        case eventsFailed(String)
        case onAppear
        case previewLoaded(RebalancePreview)
        case previewPresentationChanged(Bool)
        case previewTapped
        case proposeFailed(String)
        case selectedDayToggled(State.DayItem.ID)
    }

    enum Delegate: Equatable {
        case applied
        case close
    }
}
