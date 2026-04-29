import ComposableArchitecture
import SentinelCore

struct BatteryClient: Sendable {
    var evaluate: @Sendable (_ scheduleItems: [HomeScheduleItem], _ access: HomeScheduleAccess) async -> HomeBatteryState
    var evaluateDay: @Sendable (_ request: BatteryDayRequest) async -> DayBatteryBadgeState
}

extension BatteryClient: DependencyKey {
    static let liveValue = BatteryClient(
        evaluate: { scheduleItems, access in
            await BatteryClientLive.evaluate(scheduleItems: scheduleItems, access: access)
        },
        evaluateDay: { request in
            await BatteryClientLive.evaluateDay(request: request)
        }
    )
}

extension DependencyValues {
    nonisolated var batteryClient: BatteryClient {
        get { self[BatteryClient.self] }
        set { self[BatteryClient.self] = newValue }
    }
}
