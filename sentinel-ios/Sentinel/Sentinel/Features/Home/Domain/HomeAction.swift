import Foundation

enum HomeAction: Equatable {
    case chatTapped
    case daySelected(Int)
    case onAppear
    case profileTapped
    case rebalanceTapped
    case scheduleLoadFailed(String)
    case scheduleLoaded(CalendarSyncClient.UpcomingSnapshot)
}
